/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2014 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

using Gdk;

public enum Direction
{
    TOP,
    LEFT,
    RIGHT,
    BOTTOM,
    NONE;
}

public class TaquinView : Gtk.DrawingArea
{
    /* Theme */
    private const int GRID_SPACING = 1;
    private int grid_border_main;
    private int grid_border_thin = 6;
    private int arrows;

    /* Utilities */
    private int tile_size;
    private int board_size;
    private int x_offset { get { return (get_allocated_width () - board_size) / 2 - grid_border_main; }}
    private int y_offset { get { return (get_allocated_height () - board_size) / 2 - grid_border_main; }}

    private void calculate ()
    {
        var size = int.min (get_allocated_width (), get_allocated_height ());
        /* tile_size includes a grid spacing */
        tile_size = (size * 10 / 12) / game.size;
        board_size = tile_size * game.size - GRID_SPACING;
        grid_border_main = (size - board_size) / 2;
        arrows = size / 100;
    }

    /* Arrows (or lights) place */
    private int x_arrow = 0;
    private int y_arrow = 0;
    private bool draw_lights = false;

    /* Pre-rendered image */
    private int render_size = 0;
    private Cairo.Pattern? tiles_pattern = null;

    /* Animation */
    private bool animate = false;
    private int animation_offset;
    private bool x_axis;
    private int number;
    private int x_gap;
    private int y_gap;
    private bool animate_end = false;
    private bool finished = false;
    private double animation_end_offset;

    public TaquinView ()
    {
        can_focus = true;
        set_events (EventMask.EXPOSURE_MASK | EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.KEY_PRESS_MASK);
        set_size_request (350, 350);
    }

    private Game? _game = null;
    public Game? game
    {
        get { return _game; }
        set
        {
            if (_game != null)
                SignalHandler.disconnect_by_func (_game, null, this);
            animate = false;
            finished = false;
            animate_end = false;
            animation_end_offset = 0;
            draw_lights = false;
            x_arrow = 0;
            y_arrow = 0;
            _game = value;
            _game.move.connect (move_cb);
            _game.complete.connect (complete_cb);
            queue_draw ();
        }
    }

    private string? _theme = null;
    public string? theme
    {
        get { return _theme; }
        set { _theme = value; tiles_pattern = null; queue_draw (); }
    }

    public override bool draw (Cairo.Context cr)
    {
        if (game == null)
            return false;

        calculate ();

        if (tiles_pattern == null || render_size != tile_size)
        {
            render_size = tile_size;
            var surface = new Cairo.Surface.similar (cr.get_target (), Cairo.Content.COLOR_ALPHA, board_size, board_size);
            var c = new Cairo.Context (surface);
            load_image (c);
            tiles_pattern = new Cairo.Pattern.for_surface (surface);
        }

        cr.translate (x_offset, y_offset);
        cr.set_line_cap (Cairo.LineCap.ROUND);
        cr.set_line_join (Cairo.LineJoin.ROUND);

        /* Drawing board */
        cr.set_source_rgb (0.8, 0.8, 0.8);
        cr.rectangle (grid_border_main / 2.0, grid_border_main / 2.0, board_size + grid_border_main, board_size + grid_border_main);
        cr.fill_preserve ();
        cr.set_source_rgb (0.3, 0.3, 0.3);
        cr.set_line_width (grid_border_main);
        cr.stroke ();

        /* Drawing border */
        cr.set_source_rgb (0.1, 0.1, 0.1);
        cr.set_line_width (grid_border_thin);
        cr.arc (grid_border_main / 2.0, grid_border_main / 2.0, (grid_border_main - grid_border_thin) / 2.0, Math.PI, Math.PI * 3 / 2.0);
        cr.arc (grid_border_main * 3 / 2.0 + board_size, grid_border_main / 2.0, (grid_border_main - grid_border_thin) / 2.0, Math.PI * 3 / 2.0, 0);
        cr.arc (grid_border_main * 3 / 2.0 + board_size, grid_border_main * 3 / 2.0 + board_size, (grid_border_main - grid_border_thin) / 2.0, 0, Math.PI / 2.0);
        cr.arc (grid_border_main / 2.0, grid_border_main * 3 / 2.0 + board_size, (grid_border_main - grid_border_thin) / 2.0, Math.PI / 2.0, Math.PI);
        cr.arc (grid_border_main / 2.0, grid_border_main / 2.0, (grid_border_main - grid_border_thin) / 2.0, Math.PI, Math.PI * 3 / 2.0);
        cr.stroke ();

        /* Drawing arrows */
        cr.set_source_rgba (0.25, 0.25, 0.25, 1.0 - animation_end_offset);
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
            var texture_x = game.tiles[x_gap, y_gap] % game.size * tile_size;
            var texture_y = game.tiles[x_gap, y_gap] / game.size * tile_size;

            /* the uncovered tile */
            var tile_x = x_gap * tile_size;
            var tile_y = y_gap * tile_size;

            var matrix = Cairo.Matrix.identity ();
            matrix.translate (texture_x - tile_x, texture_y - tile_y);
            tiles_pattern.set_matrix (matrix);
            cr.set_source (tiles_pattern);
            cr.rectangle (tile_x, tile_y, tile_size - GRID_SPACING, tile_size - GRID_SPACING);
            cr.fill ();

            /* the covered tile */
            tile_x = tile_size * (x_axis ? (x_gap == 0 ? game.size - 1 : 0) : x_gap);
            tile_y = tile_size * (x_axis ? y_gap : (y_gap == 0 ? game.size - 1 : 0));

            matrix = Cairo.Matrix.identity ();
            matrix.translate (texture_x - tile_x, texture_y - tile_y);
            tiles_pattern.set_matrix (matrix);
            cr.set_source (tiles_pattern);
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

                var texture_x = game.tiles[x, y] % game.size * tile_size;
                var texture_y = game.tiles[x, y] / game.size * tile_size;

                var matrix = Cairo.Matrix.identity ();
                matrix.translate (texture_x - tile_x, texture_y - tile_y);
                tiles_pattern.set_matrix (matrix);
                cr.set_source (tiles_pattern);
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
            tiles_pattern.set_matrix (matrix);
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

    private void load_image (Cairo.Context c)
    {
        /* try      // there’s a lag switching ui screen, and I don’t use SVGs…
        {
            var h = new Rsvg.Handle.from_file (theme);

            var m = Cairo.Matrix.identity ();
            m.scale ((double) board_size / h.width, (double) board_size / h.height);
            c.set_matrix (m);
            h.render_cairo (c);

            return;
        }
        catch (Error e)
        {
            // Fall through and try loading as a pixbuf
        }*/

        try
        {
            var p = new Pixbuf.from_file_at_scale (theme, board_size, board_size, false);
            cairo_set_source_pixbuf (c, p, 0, 0);
            c.paint ();
        }
        catch (Error e)
        {
            warning ("Failed to load theme %s: %s\n\nIf you were trying to launch an unusual size, retry, it may work. But it probably implies that you have not an image adapted to the requested size in the current theme. If that's not the case, file a bug please.\n", theme, e.message);     // FIXME
        }
    }

    private void draw_movable_lights (Cairo.Context cr)
    {
        cr.save ();
        cr.set_source_rgba (0.8, 0.8, 0.8, 0.3 - 0.3 * animation_end_offset);
        /* horizontals */
        cr.save ();
        cr.translate (grid_border_main + tile_size * (x_arrow + 0.5), (grid_border_main + grid_border_thin)/ 2.0);
        draw_light (cr, true);
        cr.translate (0, board_size + grid_border_main - grid_border_thin);
        draw_light (cr, true);
        cr.restore ();
        cr.fill ();
        /* verticals */
        cr.save ();
        cr.translate ((grid_border_main + grid_border_thin)/ 2.0, grid_border_main + tile_size * (y_arrow + 0.5));
        draw_light (cr, false);
        cr.translate (board_size + grid_border_main - grid_border_thin, 0);
        draw_light (cr, false);
        cr.restore ();
        cr.fill ();
        cr.restore ();
    }
    private void draw_light (Cairo.Context cr, bool horizontal)
    {
        cr.save ();
        var size = 0.3 * tile_size / grid_border_main;
        cr.scale (horizontal ? size : 0.3, horizontal ? 0.3 : size);
        cr.arc (0.0, 0.0, grid_border_main, 0.0, 2.0 * Math.PI);
        cr.restore ();
    }

    private void draw_fixed_arrows (Cairo.Context cr)
    {
        for (var i = 0; i < game.size; i++)
        {
            draw_vertical_arrow (cr, false, i);
            draw_horizontal_arrow (cr, false, i);
        }
    }

    private void draw_movable_arrows (Cairo.Context cr)
    {
        draw_vertical_arrow (cr, true, x_arrow);
        draw_horizontal_arrow (cr, true, y_arrow);
    }

    private void draw_horizontal_arrow (Cairo.Context cr, bool inside, int number)
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

    private void draw_vertical_arrow (Cairo.Context cr, bool inside, int number)
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

    private void move_cb (bool x_axis, int number, int x_gap, int y_gap)
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
        animation_offset = 0;
        animate = true;
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

    public override bool button_press_event (EventButton event)
    {
        if (animate || animate_end)
            return true;
        if (event.button == Gdk.BUTTON_PRIMARY || event.button == Gdk.BUTTON_SECONDARY)
        {
            draw_lights = false;
            game.request_move ((int) (event.x - x_offset - grid_border_main + tile_size) / tile_size - 1,
                               (int) (event.y - y_offset - grid_border_main + tile_size) / tile_size - 1);
        }
        return true;
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        if (finished)
            return false;
        string k_name = Gdk.keyval_name (event.keyval);

        if (game.game_type == GameType.SIXTEEN && ((event.state & ModifierType.SHIFT_MASK) > 0 || (event.state & ModifierType.CONTROL_MASK) > 0))
        {
            switch (k_name) {
                case "Left":  game.request_move (- 1, y_arrow);       break;
                case "Right": game.request_move (game.size, y_arrow); break;
                case "Up":    game.request_move (x_arrow, - 1);       break;
                case "Down":  game.request_move (x_arrow, game.size); break;
                default: return false;
            }
        }
        if (k_name == "space" || k_name == "KP_Enter" || k_name == "Return")        // TODO even if game.game_type == GameType.SIXTEEN ??
        {
            game.request_move (x_arrow, y_arrow);
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
