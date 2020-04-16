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

using Gdk;

private enum Direction
{
    TOP,
    LEFT,
    RIGHT,
    BOTTOM,
    NONE;
}

private class TaquinView : Gtk.DrawingArea
{
    /* Theme */
    private const int GRID_SPACING = 1;
    private int grid_border_main;
    private int grid_border_thin = 6;
    private int arrows;

    /* Utilities */
    private int tile_size;
    private int board_size;
    [CCode (notify = false)] private int x_offset { get { return (get_allocated_width ()  - board_size) / 2 - grid_border_main; }}
    [CCode (notify = false)] private int y_offset { get { return (get_allocated_height () - board_size) / 2 - grid_border_main; }}

    /* Arrows (or lights) place */
    private int8 x_arrow = 0;
    private int8 y_arrow = 0;
    private bool draw_lights = false;

    /* Pre-rendered image */
    private int render_size = 0;
    private Cairo.Pattern? tiles_pattern = null;

    /* Animation */
    private bool animate = false;
    private int animation_offset;
    private bool x_axis;
    private int number;
    private int8 x_gap;
    private int8 y_gap;
    private bool animate_end = false;
    private bool finished = false;
    private double animation_end_offset;

    construct
    {
        init_keyboard ();
        init_mouse ();
    }

    internal TaquinView ()
    {
        can_focus = true;
        set_events (EventMask.EXPOSURE_MASK | EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.KEY_PRESS_MASK);
    }

    private Game? _game = null;
    [CCode (notify = false)] internal Game game
    {
        private get { if (_game == null) assert_not_reached (); return (!) _game; }
        internal set
        {
            if (_game != null)
                SignalHandler.disconnect_by_func (_game, null, this);

            _game = value;
            if (_game == null)
                assert_not_reached ();

            animate = false;
            finished = false;
            animate_end = false;
            animation_end_offset = 0;
            draw_lights = false;
            x_arrow = 0;
            y_arrow = 0;
            tiles_pattern = null;
            configure ();
            ((!) _game).move.connect (move_cb);
            ((!) _game).complete.connect (complete_cb);
            queue_draw ();
        }
    }

    private Pixbuf? unscaled_pixbuf = null;
    private string? _theme = null;
    [CCode (notify = false)] internal string theme
    {
        private get { if (_theme == null) assert_not_reached (); return (!) _theme; }
        internal set
        {
            _theme = value;
            if (_theme == null)
                assert_not_reached ();
            try { unscaled_pixbuf = new Pixbuf.from_file ((!) _theme); }
            catch { critical ("failed to load theme: %s", (!) _theme); assert_not_reached (); } // TODO better
            tiles_pattern = null;
            queue_draw ();
        }
    }

    protected override bool configure_event (Gdk.EventConfigure e)
    {
        configure ();
        return true;
    }

    private void configure ()
    {
        var size = int.min (get_allocated_width (), get_allocated_height ());
        /* tile_size includes a grid spacing */
        tile_size = (size * 10 / 12) / game.size;
        board_size = tile_size * game.size - GRID_SPACING;
        grid_border_main = (size - board_size) / 2;
        arrows = size / 100;
    }

    protected override bool draw (Cairo.Context cr)
    {
        if (tiles_pattern == null || render_size != tile_size)
        {
            render_size = tile_size;
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, board_size, board_size);
            var c = new Cairo.Context (surface);
            _refresh_pixmaps (c, unscaled_pixbuf, ref board_size);
            tiles_pattern = new Cairo.Pattern.for_surface (surface);
        }

        cr.translate (x_offset, y_offset);
        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);

        _draw_board (cr, ref grid_border_main, ref board_size, ref grid_border_thin);

        /* Drawing arrows */
        cr.set_source_rgba (0.5, 0.5, 0.5, 1.0 - animation_end_offset);
        cr.set_line_width (arrows);
        if (game.game_type == GameType.SIXTEEN)
        {
            if (draw_lights)
                draw_movable_lights (cr);
            draw_fixed_arrows (cr);
        }
        else
            draw_movable_arrows (cr);
        cr.stroke ();

        /* Drawing tiles */
        cr.save ();
        cr.translate (grid_border_main, grid_border_main);

        if (animate && game.game_type == GameType.SIXTEEN)  // TODO less verbose
        {
            var texture_x = game.get_tile_value (x_gap, y_gap) % game.size * tile_size;
            var texture_y = game.get_tile_value (x_gap, y_gap) / game.size * tile_size;

            /* the uncovered tile */
            var tile_x = x_gap * tile_size;
            var tile_y = y_gap * tile_size;

            var matrix = Cairo.Matrix.identity ();
            matrix.translate (texture_x - tile_x, texture_y - tile_y);
            ((!) tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) tiles_pattern);
            cr.rectangle (tile_x, tile_y, tile_size - GRID_SPACING, tile_size - GRID_SPACING);
            cr.fill ();

            /* the covered tile */
            tile_x = tile_size * (x_axis ? (x_gap == 0 ? game.size - 1 : 0) : x_gap);
            tile_y = tile_size * (x_axis ? y_gap : (y_gap == 0 ? game.size - 1 : 0));

            matrix = Cairo.Matrix.identity ();
            matrix.translate (texture_x - tile_x, texture_y - tile_y);
            ((!) tiles_pattern).set_matrix (matrix);
            cr.set_source ((!) tiles_pattern);
            cr.rectangle (tile_x, tile_y, tile_size - GRID_SPACING, tile_size - GRID_SPACING);
            cr.fill ();
        }

        for (var y = 0; y < game.size; y++)
        {
            for (var x = 0; x < game.size; x++)
            {
                if (animate && x == x_gap && y == y_gap)
                    continue;

                var tile_x = x * tile_size;
                var tile_y = y * tile_size;

                if (animate && (x != x_gap || y != y_gap))
                {
                    if (x_axis && y == y_gap)
                    {
                        if (number > 0 && x <= x_gap + number && x >= x_gap)
                            tile_x -= tile_size - animation_offset;
                        else if (number < 0 && x >= x_gap + number && x <= x_gap)
                            tile_x += tile_size - animation_offset;
                    }
                    else if (!x_axis && x == x_gap)
                    {
                        if (number > 0 && y <= y_gap + number && y >= y_gap)
                            tile_y -= tile_size - animation_offset;
                        else if (number < 0 && y >= y_gap + number && y <= y_gap)
                            tile_y += tile_size - animation_offset;
                    }
                }

                var texture_x = game.get_tile_value (x, y) % game.size * tile_size;
                var texture_y = game.get_tile_value (x, y) / game.size * tile_size;

                var matrix = Cairo.Matrix.identity ();
                matrix.translate (texture_x - tile_x, texture_y - tile_y);
                ((!) tiles_pattern).set_matrix (matrix);
                cr.set_source ((!) tiles_pattern);
                cr.rectangle (tile_x, tile_y, tile_size - GRID_SPACING, tile_size - GRID_SPACING);
                cr.fill ();
            }
        }

        if (animate_end)
        {
            animation_end_offset += 0.01;
            if (animation_end_offset >= 1)
                animation_end_offset = 1;
            var matrix = Cairo.Matrix.identity ();
            ((!) tiles_pattern).set_matrix (matrix);
            cr.paint_with_alpha (animation_end_offset);
            if (animation_end_offset != 1)
                queue_draw ();
        }
        cr.restore ();

        if (animate)
        {
            animation_offset += 8;
            if (x_axis)
                queue_draw_area (x_offset + grid_border_main + tile_size * int.min (x_gap, x_gap + number),
                                 y_offset + grid_border_main + tile_size * y_gap,
                                 tile_size * (number.abs() + 1),
                                 tile_size);
            else
                queue_draw_area (x_offset + grid_border_main + tile_size * x_gap,
                                 y_offset + grid_border_main + tile_size * int.min (y_gap, y_gap + number),
                                 tile_size,
                                 tile_size * (number.abs() + 1));
            if (animation_offset > tile_size)
                animate = false;
        }

        return false;
    }

    private static inline void _refresh_pixmaps (Cairo.Context context, Pixbuf? unscaled_pixbuf, ref int board_size)
    {
        if (unscaled_pixbuf == null)
            return;

        Gdk.Pixbuf? tmp_pixbuf;

        tmp_pixbuf = ((!) unscaled_pixbuf).scale_simple (board_size, board_size, Gdk.InterpType.BILINEAR);
        if (tmp_pixbuf == null)
            assert_not_reached ();

        cairo_set_source_pixbuf (context, (!) tmp_pixbuf, 0, 0);
        context.paint ();
    }

    private const double half_pi = Math.PI / 2.0;
    private const double three_half_pi = half_pi * 3.0;
    private static inline void _draw_board (Cairo.Context cr,
                                        ref int grid_border_main,
                                        ref int board_size,
                                        ref int grid_border_thin)
    {
        double half_grid_border_main_first_side = grid_border_main / 2.0;
        double board_size_plus_two_half_borders = board_size + grid_border_main;
        double half_grid_border_main_other_side = board_size_plus_two_half_borders + half_grid_border_main_first_side;
        double half_grid_borders_diff = (grid_border_main - grid_border_thin) / 2.0;

        /* drawing board */
        cr.set_source_rgb (0.8, 0.8, 0.8);
        cr.rectangle (/* start */ half_grid_border_main_first_side, half_grid_border_main_first_side,
                      /* size  */ board_size_plus_two_half_borders, board_size_plus_two_half_borders);
        cr.fill_preserve ();
        cr.set_source_rgb (0.3, 0.3, 0.3);
        cr.set_line_width (grid_border_main);
        cr.stroke ();

        /* drawing border */
        cr.set_source_rgb (0.1, 0.1, 0.1);
        cr.set_line_width (grid_border_thin);
        cr.arc (half_grid_border_main_first_side, half_grid_border_main_first_side, half_grid_borders_diff, Math.PI,       three_half_pi);
        cr.arc (half_grid_border_main_other_side, half_grid_border_main_first_side, half_grid_borders_diff, three_half_pi, 0.0);
        cr.arc (half_grid_border_main_other_side, half_grid_border_main_other_side, half_grid_borders_diff, 0.0,           half_pi);
        cr.arc (half_grid_border_main_first_side, half_grid_border_main_other_side, half_grid_borders_diff, half_pi,       Math.PI);
        cr.arc (half_grid_border_main_first_side, half_grid_border_main_first_side, half_grid_borders_diff, Math.PI,       three_half_pi);
        cr.stroke ();
    }

    private inline void draw_movable_lights (Cairo.Context cr)
    {
        _draw_movable_lights (cr, ref animation_end_offset, ref grid_border_main, ref tile_size, ref x_arrow, ref grid_border_thin, ref board_size, ref y_arrow);
    }
    private static inline void _draw_movable_lights (Cairo.Context cr,
                                                 ref double animation_end_offset,
                                                 ref int    grid_border_main,
                                                 ref int    tile_size,
                                                 ref int8    x_arrow,
                                                 ref int    grid_border_thin,
                                                 ref int    board_size,
                                                 ref int8    y_arrow)
    {
        double half_grid_borders_sum = (grid_border_main + grid_border_thin) / 2.0;
        int board_size_plus_borders_diff = board_size + grid_border_main - grid_border_thin;

        cr.save ();
        cr.set_source_rgba (0.7, 0.7, 0.7, 0.3 - 0.3 * animation_end_offset);
        /* horizontals */
        cr.save ();
        cr.translate (grid_border_main + tile_size * (x_arrow + 0.5), half_grid_borders_sum);
        draw_light (cr, /* horizontal */ true, ref tile_size, ref grid_border_main);
        cr.translate (0, board_size_plus_borders_diff);
        draw_light (cr, /* horizontal */ true, ref tile_size, ref grid_border_main);
        cr.restore ();
        cr.fill ();
        /* verticals */
        cr.save ();
        cr.translate (half_grid_borders_sum, grid_border_main + tile_size * (y_arrow + 0.5));
        draw_light (cr, /* horizontal */ false, ref tile_size, ref grid_border_main);
        cr.translate (board_size_plus_borders_diff, 0);
        draw_light (cr, /* horizontal */ false, ref tile_size, ref grid_border_main);
        cr.restore ();
        cr.fill ();
        cr.restore ();
    }
    private static void draw_light (Cairo.Context cr, bool horizontal, ref int tile_size, ref int grid_border_main)
    {
        cr.save ();
        var size = 0.3 * tile_size / grid_border_main;
        cr.scale (horizontal ? size : 0.3, horizontal ? 0.3 : size);
        cr.arc (0.0, 0.0, grid_border_main, 0.0, 2.0 * Math.PI);
        cr.restore ();
    }

    private inline void draw_fixed_arrows (Cairo.Context cr)
    {
        _draw_fixed_arrows (cr, game.size, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
    }
    private static inline void _draw_fixed_arrows (Cairo.Context cr, int game_size,
                                               ref int grid_border_main,
                                               ref int tile_size,
                                               ref int grid_border_thin,
                                               ref int board_size)
    {
        for (var i = 0; i < game_size; i++)
        {
            draw_vertical_arrow   (cr, /* inside */ false, i, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
            draw_horizontal_arrow (cr, /* inside */ false, i, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
        }
    }

    private inline void draw_movable_arrows (Cairo.Context cr)
    {
        _draw_movable_arrows (cr, ref x_arrow, ref y_arrow, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
    }
    private static inline void _draw_movable_arrows (Cairo.Context cr,
                                                 ref int8 x_arrow,
                                                 ref int8 y_arrow,
                                                 ref int grid_border_main,
                                                 ref int tile_size,
                                                 ref int grid_border_thin,
                                                 ref int board_size)
    {
        draw_vertical_arrow   (cr, /* inside */ true, x_arrow, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
        draw_horizontal_arrow (cr, /* inside */ true, y_arrow, ref grid_border_main, ref tile_size, ref grid_border_thin, ref board_size);
    }

    private static void draw_horizontal_arrow (Cairo.Context cr, bool inside, int number,
                                           ref int grid_border_main,
                                           ref int tile_size,
                                           ref int grid_border_thin,
                                           ref int board_size)
    {
        var x1 = grid_border_main * 1.0 / 3 + grid_border_thin * 2.0 / 3;
        var x2 = grid_border_main * 2.0 / 3 + grid_border_thin * 1.0 / 3;
        cr.move_to (inside ? x1 : x2, grid_border_main + tile_size * (number + 1.0 / 3));
        cr.line_to (inside ? x2 : x1, grid_border_main + tile_size * (number + 1.0 / 2));
        cr.line_to (inside ? x1 : x2, grid_border_main + tile_size * (number + 2.0 / 3));
        x1 = board_size + grid_border_main * 5.0 / 3 - grid_border_thin * 2.0 / 3;
        x2 = board_size + grid_border_main * 4.0 / 3 - grid_border_thin * 1.0 / 3;
        cr.move_to (inside ? x1 : x2, grid_border_main + tile_size * (number + 1.0 / 3));
        cr.line_to (inside ? x2 : x1, grid_border_main + tile_size * (number + 1.0 / 2));
        cr.line_to (inside ? x1 : x2, grid_border_main + tile_size * (number + 2.0 / 3));
    }

    private static void draw_vertical_arrow (Cairo.Context cr, bool inside, int number,
                                         ref int grid_border_main,
                                         ref int tile_size,
                                         ref int grid_border_thin,
                                         ref int board_size)
    {
        var y1 = grid_border_main * 1.0 / 3 + grid_border_thin * 2.0 / 3;
        var y2 = grid_border_main * 2.0 / 3 + grid_border_thin * 1.0 / 3;
        cr.move_to (grid_border_main + tile_size * (number + 1.0 / 3), inside ? y1 : y2);
        cr.line_to (grid_border_main + tile_size * (number + 1.0 / 2), inside ? y2 : y1);
        cr.line_to (grid_border_main + tile_size * (number + 2.0 / 3), inside ? y1 : y2);
        y1 = board_size + grid_border_main * 5.0 / 3 - grid_border_thin * 2.0 / 3;
        y2 = board_size + grid_border_main * 4.0 / 3 - grid_border_thin * 1.0 / 3;
        cr.move_to (grid_border_main + tile_size * (number + 1.0 / 3), inside ? y1 : y2);
        cr.line_to (grid_border_main + tile_size * (number + 1.0 / 2), inside ? y2 : y1);
        cr.line_to (grid_border_main + tile_size * (number + 2.0 / 3), inside ? y1 : y2);
    }

    private void move_cb (bool x_axis, int8 number, int8 x_gap, int8 y_gap, uint moves_count, bool disable_animation)
    {
        this.x_axis = x_axis;
        this.number = number;
        this.x_gap = x_gap;
        this.y_gap = y_gap;

        if (game.game_type == GameType.FIFTEEN)
        {
            x_arrow = x_gap;
            y_arrow = y_gap;
        }
        if (disable_animation)
        {
            finished = false;
            animation_end_offset = 0;
            animate_end = false;
        }
        else
        {
            animation_offset = 0;
            animate = true;
        }
        queue_draw ();
    }

    private void complete_cb ()
    {
        finished = true;
        Timeout.add_seconds (1, () =>
            {
                animation_end_offset = 0;
                animate_end = true;
                queue_draw ();
                /* Disconnect from mainloop */
                return false;
            });
    }

    /*\
    * * mouse user actions
    \*/

    private Gtk.GestureMultiPress click_controller;   // for keeping in memory

    private void init_mouse ()  // called on construct
    {
        click_controller = new Gtk.GestureMultiPress (this);
        click_controller.set_button (/* all buttons */ 0);
        click_controller.pressed.connect (on_click);
    }

    private inline void on_click (Gtk.GestureMultiPress _click_controller, int n_press, double event_x, double event_y)
    {
        if (finished || animate || animate_end)
            return;

        uint button = _click_controller.get_current_button ();
        if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_SECONDARY)
            return;

        draw_lights = false;
        game.request_move ((int8) ((int) (event_x - x_offset - grid_border_main + tile_size) / tile_size - 1),
                           (int8) ((int) (event_y - y_offset - grid_border_main + tile_size) / tile_size - 1),
                           /* keyboard */ false);
    }

    /*\
    * * keyboard user actions
    \*/

    private Gtk.EventControllerKey key_controller;    // for keeping in memory

    private void init_keyboard ()  // called on construct
    {
        key_controller = new Gtk.EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
    }

    private inline bool on_key_pressed (Gtk.EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        if (finished)
            return false;
        string k_name = (!) (Gdk.keyval_name (keyval) ?? "");

        if (game.game_type == GameType.SIXTEEN && ((state & ModifierType.SHIFT_MASK) > 0 || (state & ModifierType.CONTROL_MASK) > 0))
        {
            switch (k_name) {
                case "Left":  game.request_move (- 1,       y_arrow,    /* keyboard */ true); break;
                case "Right": game.request_move (game.size, y_arrow,    /* keyboard */ true); break;
                case "Up":    game.request_move (x_arrow,   - 1,        /* keyboard */ true); break;
                case "Down":  game.request_move (x_arrow,   game.size,  /* keyboard */ true); break;
                default: return false;
            }
        }
        if (k_name == "space" || k_name == "KP_Enter" || k_name == "Return")        // TODO even if game.game_type == GameType.SIXTEEN ??
        {
            game.request_move (x_arrow, y_arrow, /* keyboard */ true);
            return true;
        }
        switch (k_name) {
            case "Left":  if (x_arrow > 0) x_arrow --;             break;
            case "Right": if (x_arrow < game.size - 1) x_arrow ++; break;
            case "Up":    if (y_arrow > 0) y_arrow --;             break;
            case "Down":  if (y_arrow < game.size - 1) y_arrow ++; break;
            default: return false;
        }
        draw_lights = true;
        queue_draw ();      // TODO animations (light / arrows)
        return true;
    }
}
