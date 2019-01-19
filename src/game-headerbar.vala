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
private class GameHeaderBar : BaseHeaderBar
{
    [GtkChild] private Box      controls_box;
    [GtkChild] private Button   new_game_button;
    [GtkChild] private Button   back_button;

    public bool window_has_name { private get; protected construct; default = false; }
    public string window_name   { private get; internal  construct; default = ""; }

    construct
    {
        init_modes ();

        if (window_name != "")
            window_has_name = true;
    }

    internal GameHeaderBar (string _window_name, GameWindowFlags flags, NightLightMonitor _night_light_monitor)
    {
        /* Translators: usual menu entry of the hamburger menu */
        Object (about_action_label:     _("About Taquin"),
                night_light_monitor:    _night_light_monitor,
                has_help:               true,
                has_keyboard_shortcuts: false,
                window_name:            _window_name);

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
    * * adaptative stuff
    \*/

    private bool is_extra_thin = true;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        base.set_window_size (new_size);

        if (!window_has_name)
            return;

        bool _is_extra_thin = AdaptativeWidget.WindowSize.is_extra_thin (new_size);
        if (_is_extra_thin == is_extra_thin)
            return;
        is_extra_thin = _is_extra_thin;
        set_default_widgets_default_states (this);
    }

    protected override void set_default_widgets_default_states (BaseHeaderBar _this)
    {
        string? headerbar_label_text;
        if (((GameHeaderBar) _this).is_extra_thin)
            headerbar_label_text = null;
        else
            headerbar_label_text = ((GameHeaderBar) _this).window_name;
        _this.set_default_widgets_states (/* title_label text or null */ headerbar_label_text,
                                          /* show go_back_button      */ false,
                                          /* show ltr_left_separator  */ false,
                                          /* show info_button         */ true,
                                          /* show ltr_right_separator */ _this.disable_action_bar,
                                          /* show quit_button_stack   */ _this.disable_action_bar);
    }

    /*\
    * * Showing the Stack
    \*/

    private bool current_view_is_new_game_screen = false;

    internal /* grabs focus */ bool show_new_game_screen (bool game_finished)
    {
        current_view_is_new_game_screen = true;

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
        current_view_is_new_game_screen = false;

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

    protected override void populate_menu (ref GLib.Menu menu)
    {
        append_sound_section (ref menu);
    }

    private static inline void append_sound_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();
        /* Translators: hamburger menu entry; sound togglebutton (with a mnemonic that appears pressing Alt) */
        section.append (_("_Sound"), "app.sound");
        section.freeze ();
        menu.append_section (null, section);
    }

    /*\
    * * modes
    \*/

    private void init_modes ()
    {
        this.change_mode.connect (mode_changed_game);
    }

    private static void mode_changed_game (BaseHeaderBar _this, uint8 mode_id)
    {
        GameHeaderBar real_this = (GameHeaderBar) _this;
        if (mode_id == default_mode_id)
        {
            if (real_this.current_view_is_new_game_screen)
                real_this.back_button.show ();
            else
            {
                real_this.controls_box.show ();
                real_this.new_game_button.show ();
            }
        }
        else
        {
            real_this.back_button.hide ();
            real_this.controls_box.hide ();
            real_this.new_game_button.hide ();
        }
    }
}
