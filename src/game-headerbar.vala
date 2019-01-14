/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2019 – Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of a GNOME game.
 *
 * This application is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This application is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this application. If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

[GtkTemplate (ui = "/org/gnome/Taquin/ui/game-headerbar.ui")]
private class GameHeaderBar : HeaderBar
{
    [GtkChild] private Box          controls_box;
    [GtkChild] private Button       new_game_button;
    [GtkChild] private Button       back_button;
    [GtkChild] private MenuButton   info_button;

    internal GameHeaderBar (GameWindowFlags flags)
    {
        if (GameWindowFlags.SHOW_UNDO in flags)
        {
            Box history_box = new Box (Orientation.HORIZONTAL, 0);
            history_box.get_style_context ().add_class ("linked");

            Button undo_button = new Button.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.BUTTON);
            undo_button.action_name = "ui.undo";
            /* Translators: during a game, tooltip text of the Undo button */
            undo_button.set_tooltip_text (_("Undo your most recent move"));
            undo_button.valign = Align.CENTER;
            undo_button.show ();
            history_box.pack_start (undo_button, true, true, 0);

            /* if (GameWindowFlags.SHOW_REDO in flags)
            {
                Button redo_button = new Button.from_icon_name ("edit-redo-symbolic", Gtk.IconSize.BUTTON);
                redo_button.action_name = "app.redo";
                / Translators: during a game, tooltip text of the Redo button /
                redo_button.set_tooltip_text (_("Redo your most recent undone move"));
                redo_button.valign = Align.CENTER;
                redo_button.show ();
                history_box.pack_start (redo_button, true, true, 0);
            } */

            history_box.show ();
            controls_box.pack_start (history_box, true, true, 0);
        }
        /* if (GameWindowFlags.SHOW_HINT in flags)
        {
            Button hint_button = new Button.from_icon_name ("dialog-question-symbolic", Gtk.IconSize.BUTTON);
            hint_button.action_name = "app.hint";
            / Translators: during a game, tooltip text of the Hint button /
            hint_button.set_tooltip_text (_("Receive a hint for your next move"));
            hint_button.valign = Align.CENTER;
            hint_button.show ();
            controls_box.pack_start (hint_button, true, true, 0);
        } */
    }

    /*\
    * * Showing the Stack
    \*/

    internal /* grabs focus */ bool show_new_game_screen (bool game_finished)
    {
        set_subtitle (null);      // TODO save / restore?

        controls_box.hide ();

        if (!game_finished && back_button.visible)
        {
            back_button.grab_focus ();
            return true;
        }
        else
            return false;
    }

    internal /* grabs focus */ bool show_view (bool game_finished)
    {
        back_button.hide ();        // TODO transition?
        new_game_button.show ();    // TODO transition?
        controls_box.show ();

        if (game_finished)
        {
            new_game_button.grab_focus ();
            return true;
        }
        else
            return false;
    }

    /*\
    * * Switching the Stack
    \*/

    internal void new_game ()
    {
        back_button.show ();
        new_game_button.hide ();        // TODO transition?
    }

    /*\
    * * Some public calls
    \*/

    internal void new_game_button_grab_focus ()
    {
        new_game_button.grab_focus ();
    }

    internal bool new_game_button_is_focus ()
    {
        return new_game_button.is_focus;
    }

    /*\
    * * hamburger menu
    \*/

    internal void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        info_button.active = !info_button.active;
    }
}
