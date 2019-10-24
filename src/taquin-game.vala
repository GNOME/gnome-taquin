/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Taquin.

   Copyright (C) 2014-2016 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

   GNOME Taquin is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME Taquin is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME Taquin.  If not, see <https://www.gnu.org/licenses/>.
*/

private enum GameType
{
    FIFTEEN,
    SIXTEEN;

    internal string to_string ()
    {
        switch (this)
        {
            case FIFTEEN: return "fifteen";
            case SIXTEEN: return "sixteen";
            default: assert_not_reached ();
        }
    }
}

private class Game : Object
{
    [CCode (notify = false)] public int8 size           { internal get; protected construct; }
    [CCode (notify = false)] public GameType game_type  { internal get; protected construct; }

    /* tiles: -1 is the empty tile, if any */
    private int8 [,] tiles;
    internal int8 get_tile_value (int8 x, int8 y) { return tiles [x, y]; }

    /* undoing */
    private UndoItem? state = null;
    private UndoItem? previous_state = null;
    private uint moves_count = 0;

    /* position of the empty tile, if any */
    private int8 x_gap = 0;
    private int8 y_gap = 0;

    /* signals */
    internal signal void complete ();
    internal signal void move (bool x_axis, int8 number, int8 x_gap, int8 y_gap, uint moves_count, bool disable_animation);
    internal signal void bad_click (BadClick reason, bool keyboard_call);

    internal enum BadClick {
        EMPTY_TILE,
        NOT_MOVING,
        IS_OUTSIDE,
        USE_ARROWS;
    }

    /*\
    * * Creation / exporting
    \*/

    construct
    {
        do { generate_game (game_type, size, out tiles); } while (check_complete (ref tiles));
    }

    internal Game (GameType game_type = GameType.FIFTEEN, int8 size = 4)
        requires (size >= 2)
        requires (size <= 9)
    {
        Object (game_type: game_type, size: size);
    }

    private static void generate_game (GameType game_type, int8 size, out int8 [,] tiles)
    {
        int8 ntiles = size * size;             // size <= 9
        int8? [] line = new int8? [ntiles];
        int i = 0;
        for (int8 n = ntiles - 1; n >= 0; n--)
        {
            do { i = Random.int_range (0, (int) ntiles); } while (line [i] != null);       // TODO "i == n ||" ?
            line [i] = n;
        }

        if (game_type == GameType.FIFTEEN)
        {
            /* Place the empty tile at the top-left corner; x_gap == 0 && y_gap == 0 */
            line [i] = line [0];
            line [0] = -1;
        }

        /* Play with parities */
        bool parity_grid = (bool) ((size % 2) ^ (size % 2)) & 1 == 0;
        bool parity_game = false;
        for (uint8 j = 0; j < ntiles - 1; j++)
            for (uint8 k = j + 1; k < ntiles; k++)
                if (line [j] > line [k])
                    parity_game = !parity_game;

        if (parity_game != parity_grid)
        {
            int8? save = line [1];
            line [1] = line [size + 1];
            line [size + 1] = save;
        }

        /* Now construct the game description */
        tiles = new int8 [size, size];

        for (uint8 j = 0; j < ntiles; j++)
        {
            int8? line_j = line [j];
            if (line_j == null)
                assert_not_reached ();
            tiles [j % size, j / size] = (!) line_j;
        }
    }

    internal string to_string ()
    {
        string s = "\n";

        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
                s += " " + (tiles [y, x] + 1).to_string ();
            s += "\n";
        }

        return s;
    }

    /*\
    * * Game code
    \*/

    internal void request_move (int8 x, int8 y, bool keyboard_call)
    {
        if (game_type == GameType.FIFTEEN)
        {
            if (x < 0 || x >= size || y < 0 || y >= size)
            {
                bad_click (BadClick.IS_OUTSIDE, keyboard_call);
                return;
            }
            if (x == x_gap && y == y_gap)
            {
                bad_click (BadClick.EMPTY_TILE, keyboard_call);
                return;
            }
            if (x != x_gap && y != y_gap)
            {
                bad_click (BadClick.NOT_MOVING, keyboard_call);
                return;
            }
            fifteen_move (x, y, /* undoing */ false);
        }
        else
        {
            // TODO real touch support
            if (x >= 0 && x < size && y >= 0 && y < size)
            {
                bad_click (BadClick.USE_ARROWS, keyboard_call);
                return;
            }
            sixteen_move (x, y, /* undoing */ false);
        }
    }

    private void fifteen_move (int8 x, int8 y, bool undoing = false, bool restarting = false)
        requires (!restarting || undoing)
        requires ((x >= 0) && (x < size))
        requires ((y >= 0) && (y < size))
    {
        /* we do the move before notifying */
        bool was_complete = check_complete (ref tiles);

        bool move_x_axis = x != x_gap;
        int8 move_number = move_x_axis ? x_gap - x : y_gap - y;

        if (undoing)
        {
            if (moves_count == 0)
                assert_not_reached ();
            if (moves_count != uint.MAX)
                moves_count--;
        }
        else
        {
            add_move (/* move_x_axis, move_number,*/ x_gap, y_gap);
            if (moves_count != uint.MAX)
                moves_count++;
        }

        if (move_x_axis)
        {
            if (x < x_gap)
                do { tiles [x_gap, y] = tiles [x_gap - 1, y]; x_gap--; } while (x_gap != x);
            else
                do { tiles [x_gap, y] = tiles [x_gap + 1, y]; x_gap++; } while (x_gap != x);
        }
        else
        {
            if (y < y_gap)
                do { tiles [x, y_gap] = tiles [x, y_gap - 1]; y_gap--; } while (y_gap != y);
            else
                do { tiles [x, y_gap] = tiles [x, y_gap + 1]; y_gap++; } while (y_gap != y);
        }
        tiles [x_gap, y_gap] = -1;

        move (move_x_axis, move_number, x_gap, y_gap, moves_count, restarting || (was_complete && undoing));
        if (check_complete (ref tiles))
            complete ();
    }

    private void sixteen_move (int8 x, int8 y, bool undoing = false, bool restarting = false)
        requires (!restarting || undoing)
        requires ((x < 0) || (x >= size) || (y < 0) || (y >= size))
    {
        bool move_x_axis;
        if (x < 0 || x >= size)
        {
            if (y < 0 || y >= size)
                return;
            move_x_axis = true;
        }
        else
        {
            if (y >= 0 && y < size)
                return;
            move_x_axis = false;
        }

        /* we do the move before notifying */
        bool was_complete = check_complete (ref tiles);

        int8 new_coord = 0;
        if (move_x_axis)
        {
            if (x < 0)
            {
                int8 tmp = tiles [0, y];
                for (uint8 i = 0; i < size - 1; i++)
                    tiles [i, y] = tiles [i + 1, y];
                tiles [size - 1, y] = tmp;
                new_coord = size - 1;
            }
            else
            {
                int8 tmp = tiles [size - 1, y];
                for (uint8 i = size - 1; i > 0; i--)
                    tiles [i, y] = tiles [i - 1, y];
                tiles [0, y] = tmp;
                new_coord = 0;
            }
        }
        else
        {
            if (y < 0)
            {
                int8 tmp = tiles [x, 0];
                for (uint8 i = 0; i < size - 1; i++)
                    tiles [x, i] = tiles [x, i + 1];
                tiles [x, size - 1] = tmp;
                new_coord = size - 1;
            }
            else
            {
                int8 tmp = tiles [x, size - 1];
                for (uint8 i = size - 1; i > 0; i--)
                    tiles [x, i] = tiles [x, i - 1];
                tiles [x, 0] = tmp;
                new_coord = 0;
            }
        }

        if (undoing)
        {
            if (moves_count == 0)
                assert_not_reached ();
            if (moves_count != uint.MAX)
                moves_count--;
        }
        else
        {
            add_move (move_x_axis ? (new_coord == 0 ? -1 : size) : x, move_x_axis ? y : (new_coord == 0 ? -1 : size));
            if (moves_count != uint.MAX)
                moves_count++;
        }

        move (move_x_axis,
              new_coord == 0 ? size - 1 : 1 - size,
              move_x_axis ? new_coord : x,
              move_x_axis ? y : new_coord,
              moves_count,
              restarting || (was_complete && undoing));
        if (check_complete (ref tiles))
            complete ();
    }

    private static bool check_complete (ref int8 [,] tiles)
    {
        uint8 size = (uint8) tiles.length [0];  /* 2 <= size <= 9 */
        for (uint8 i = 1; i < size * size; i++)
            if (i != tiles [i % size, i / size])
                return false;
        return true;
    }

    /*\
    * * Undo; Iagno has proven this way to do was very slow, don’t copy it
    \*/

    private struct UndoItem
    {
        public int8 x;
        public int8 y;
        public UndoItem? next;
        public UndoItem? previous;
    }

    internal void undo ()
    {
        if (state == null)
            return;

        if (game_type == GameType.FIFTEEN)
            fifteen_move (((!) state).x, ((!) state).y, /* undoing */ true);
        else
            sixteen_move (((!) state).x, ((!) state).y, /* undoing */ true);

        state = previous_state;
        previous_state = state == null ? null : ((!) state).previous;
    }

    internal void restart ()
    {
        while (state != null)
        {
            if (game_type == GameType.FIFTEEN)
                fifteen_move (((!) state).x, ((!) state).y, /* undoing */ true, /* restarting */ true);
            else
                sixteen_move (((!) state).x, ((!) state).y, /* undoing */ true, /* restarting */ true);

            state = previous_state;
            previous_state = state == null ? null : ((!) state).previous;
        }
    }

    private void add_move (int8 x_gap, int8 y_gap)
    {
        previous_state = state == null ? null : state;
        state = UndoItem () { x = x_gap, y = y_gap, next = null, previous = previous_state };
        if (previous_state == null)
            return;
        previous_state = UndoItem () { x = ((!) previous_state).x, y = ((!) previous_state).y, next = state, previous = ((!) previous_state).previous };
    }
}
