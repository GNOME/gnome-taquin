/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2014-2016 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of Taquin.
 *
 * Taquin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Taquin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with Taquin. If not, see <http://www.gnu.org/licenses/>.
 */

public enum GameType
{
    FIFTEEN,
    SIXTEEN;

    public string to_string ()
    {
        switch (this)
        {
            case FIFTEEN:
                return "fifteen";
            case SIXTEEN:
                return "sixteen";
            default:
                assert_not_reached ();
        }
    }
}

public class Game : Object
{
    /* tiles: -1 is the empty tile, if any */
    public int[,] tiles { get; private set; }
    public int size { get; private set; }
    public GameType game_type { get; private set; }

    /* undoing */
    private UndoItem? state = null;
    private UndoItem? previous_state = null;

    /* position of the empty tile, if any */
    private int x_gap = 0;
    private int y_gap = 0;

    /* signals */
    public signal void complete ();
    public signal void move (bool x_axis, int number, int x_gap, int y_gap, bool restarting);
    public signal void empty_tile ();
    public signal void cannot_move (int x, int y);
    public signal void cannot_undo_more ();

    /*\
    * * Creation / exporting
    \*/

    public Game (GameType game_type = GameType.FIFTEEN, int size = 4)
        requires (size >= 2)
    {
        this.size = size;
        this.game_type = game_type;
        tiles = new int[size, size];

        var ntiles = size * size;
        var line = new int?[ntiles];
        var i = 0;
        for (var n = ntiles - 1; n >= 0; n--)
        {
            do { i = Random.int_range (0, ntiles); } while (line[i] != null);       // TODO "i == n ||" ?
            line[i] = n;
        }

        if (game_type == GameType.FIFTEEN)
        {
            /* Place the empty tile at the top-left corner */
            line[i] = line[0];
            line[0] = -1;
            x_gap = 0;
            y_gap = 0;
        }

        /* Play with parities */
        bool parity_grid = (bool) ((size % 2) ^ (size % 2)) & 1 == 0;
        bool parity_game = false;
        for (var j = 0; j < ntiles - 1; j++)
            for (var k = j + 1; k < ntiles; k++)
                if (line[j] > line[k])
                    parity_game = !parity_game;

        if (parity_game != parity_grid)
        {
            var save = line[1];
            line[1] = line[size + 1];
            line[size + 1] = save;
        }

        /* Now construct the game description */
        for (var j = 0; j < ntiles; j++)
        {
            int? line_j = line[j];
            if (line_j == null)
                assert_not_reached ();
            tiles[j % size, j / size] = (!) line_j;
        }
    }

    public string to_string ()
    {
        string s = "\n";

        for (int x = 0; x < size; x++)
        {
            for (int y = 0; y < size; y++)
                s += " " + (tiles[y, x] + 1).to_string ();
            s += "\n";
        }

        return s;
    }

    /*\
    * * Game code
    \*/

    public void request_move (int x, int y)
    {
        if (game_type == GameType.FIFTEEN)
            fifteen_move (x, y, /* undoing */ false);
        else
            sixteen_move (x, y, /* undoing */ false);
    }

    private void fifteen_move (int x, int y, bool undoing = false, bool restarting = false)
        requires (!restarting || undoing)
    {
        if (x < 0 || x >= size || y < 0 || y >= size)
            return;

        if (x == x_gap && y == y_gap)
        {
            empty_tile ();
            return;
        }
        if (x != x_gap && y != y_gap)
        {
            cannot_move (x, y);
            return;
        }

        /* we do the move before notifying */
        var move_x_axis = x != x_gap;
        var move_number = move_x_axis ? x_gap - x : y_gap - y;

        if (!undoing)
            add_move (/* move_x_axis, move_number,*/ x_gap, y_gap);

        if (move_x_axis)
        {
            if (x < x_gap)
                do { tiles[x_gap, y] = tiles[x_gap - 1, y]; x_gap--; } while (x_gap != x);
            else
                do { tiles[x_gap, y] = tiles[x_gap + 1, y]; x_gap++; } while (x_gap != x);
        }
        else
        {
            if (y < y_gap)
                do { tiles[x, y_gap] = tiles[x, y_gap - 1]; y_gap--; } while (y_gap != y);
            else
                do { tiles[x, y_gap] = tiles[x, y_gap + 1]; y_gap++; } while (y_gap != y);
        }
        tiles[x_gap, y_gap] = -1;

        move (move_x_axis, move_number, x_gap, y_gap, restarting);
        if (!undoing)
            check_complete ();
    }

    private void sixteen_move (int x, int y, bool undoing = false, bool restarting = false)
        requires (!restarting || undoing)
    {
        /* TODO touch */
        if (x >= 0 && x < size && y >= 0 && y < size)
            return;

        var move_x_axis = false;
        if (x < 0 || x >= size)
        {
            if (y < 0 || y >= size)
                return;
            else
                move_x_axis = true;
        }
        else if (y >= 0 && y < size)
            return;

        /* we do the move before notifying */
        var new_coord = 0;
        if (move_x_axis)
        {
            if (x < 0)
            {
                var tmp = tiles[0, y];
                for (var i = 0; i < size - 1; i++)
                    tiles[i, y] = tiles[i + 1, y];
                tiles[size - 1, y] = tmp;
                new_coord = size - 1;
            }
            else
            {
                var tmp = tiles[size - 1, y];
                for (var i = size - 1; i > 0; i--)
                    tiles[i, y] = tiles[i - 1, y];
                tiles[0, y] = tmp;
                new_coord = 0;
            }
        }
        else
        {
            if (y < 0)
            {
                var tmp = tiles[x, 0];
                for (var i = 0; i < size - 1; i++)
                    tiles[x, i] = tiles[x, i + 1];
                tiles[x, size - 1] = tmp;
                new_coord = size - 1;
            }
            else
            {
                var tmp = tiles[x, size - 1];
                for (var i = size - 1; i > 0; i--)
                    tiles[x, i] = tiles[x, i - 1];
                tiles[x, 0] = tmp;
                new_coord = 0;
            }
        }
        if (!undoing)
            add_move (move_x_axis ? (new_coord == 0 ? -1 : size) : x, move_x_axis ? y : (new_coord == 0 ? -1 : size));
        move (move_x_axis, new_coord == 0 ? size - 1 : 1 - size, move_x_axis ? new_coord : x, move_x_axis ? y : new_coord, restarting);
        if (!undoing)
            check_complete ();
    }

    private void check_complete ()
    {
        for (var i = 1; i < size * size; i++)
            if (i != tiles[i % size, i / size])
                return;
        complete ();
    }

    /*\
    * * Undo; Iagno has proven this way to do was very slow, don’t copy it
    \*/

    private struct UndoItem
    {
        public int x;
        public int y;
        public UndoItem? next;
        public UndoItem? previous;
    }

    public void undo ()
    {
        if (state == null)
            return;

        if (game_type == GameType.FIFTEEN)
            fifteen_move (((!) state).x, ((!) state).y, /* undoing */ true);
        else
            sixteen_move (((!) state).x, ((!) state).y, /* undoing */ true);

        state = previous_state;
        previous_state = state == null ? null : ((!) state).previous;

        if (state == null)
            cannot_undo_more ();
    }

    public void restart ()
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

        cannot_undo_more ();
    }

    private void add_move (int x_gap, int y_gap)
    {
        previous_state = state == null ? null : state;
        state = UndoItem () { x = x_gap, y = y_gap, next = null, previous = previous_state };
        if (previous_state == null)
            return;
        previous_state = UndoItem () { x = ((!) previous_state).x, y = ((!) previous_state).y, next = state, previous = ((!) previous_state).previous };
    }
}
