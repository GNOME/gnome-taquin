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
    [GtkChild] private MenuButton   history_button;
    [GtkChild] private Button       new_game_button;
    [GtkChild] private Button       back_button;

    public bool window_has_name { private get; protected construct; default = false; }
    public string window_name   { private get; internal  construct; default = ""; }

    construct
    {
        ((Label) new_game_button.get_child ()).set_ellipsize (Pango.EllipsizeMode.END); // can happen on small screen with big moves count

        generate_moves_menu ();

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
                has_keyboard_shortcuts: true,
                window_name:            _window_name);

/*        if (GameWindowFlags.SHOW_UNDO in flags)
        {
            Box history_box = new Box (Orientation.HORIZONTAL, 0);
            history_box.get_style_context ().add_class ("linked");

            Button undo_button = new Button.from_icon_name ("edit-undo-symbolic", Gtk.IconSize.BUTTON);
            undo_button.action_name = "ui.undo";
*/            /* Translators: during a game, tooltip text of the Undo button */
/*            undo_button.set_tooltip_text (_("Undo your most recent move"));
            undo_button.valign = Align.CENTER;
            undo_button.show ();
            history_box.pack_start (undo_button, true, true, 0);

*/            /* if (GameWindowFlags.SHOW_REDO in flags)
            {
                Button redo_button = new Button.from_icon_name ("edit-redo-symbolic", Gtk.IconSize.BUTTON);
                redo_button.action_name = "app.redo";
                / Translators: during a game, tooltip text of the Redo button /
                redo_button.set_tooltip_text (_("Redo your most recent undone move"));
                redo_button.valign = Align.CENTER;
                redo_button.show ();
                history_box.pack_start (redo_button, true, true, 0);
            } */

/*            history_box.show ();
            controls_box.pack_start (history_box, true, true, 0);
        }
*/        /* if (GameWindowFlags.SHOW_HINT in flags)
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

        history_button.hide ();

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
        history_button.show ();

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
        best_score = 0;
        last_moves_count = 0;
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

    private uint last_moves_count = 0;
    internal void set_moves_count (ref uint moves_count)
    {
        history_button.set_label (moves_count.to_string ());
        history_button.set_sensitive ((moves_count != 0) || (best_score != 0));
        last_moves_count = moves_count;
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
                real_this.history_button.show ();
                real_this.new_game_button.show ();
            }
        }
        else
        {
            real_this.back_button.hide ();
            real_this.history_button.hide ();
            real_this.new_game_button.hide ();
        }
    }

    /*\
    * * moves menu
    \*/

    private uint best_score = 0;
    internal void save_best_score (out string best_score_string)
    {
        get_best_score_string (ref best_score, ref last_moves_count, out best_score_string);

        if ((best_score == 0) || (last_moves_count < best_score))
            best_score = last_moves_count;
        generate_moves_menu ();
    }
    private static inline void get_best_score_string (ref uint best_score, ref uint last_moves_count, out string best_score_string)
    {
        if (best_score == 0)
        {
            best_score_string = usual_best_score_string;
            return;
        }

        if (last_moves_count < best_score)
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You improved your best score!");
            if (best_score_string != "Bravo! You improved your best score!")
                return;
        }
        else if (last_moves_count == best_score)
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You equalized your best score.");
            if (best_score_string != "Bravo! You equalized your best score.")
                return;
        }
        else
        {
            /* Translators: in-window notification; on both games, if the user solved the puzzle more than one time */
            best_score_string =    _("Bravo! You finished the game again.");
            if (best_score_string != "Bravo! You finished the game again.")
                return;
        }

        if (usual_best_score_string_untranslated != usual_best_score_string)
            best_score_string = usual_best_score_string;
    }
    /* Translators: in-window notification; on both games, if the user solves the puzzle the first time */
    private const string usual_best_score_string              = _("Bravo! You finished the game!");
    private const string usual_best_score_string_untranslated =   "Bravo! You finished the game!" ;

    private void generate_moves_menu ()
    {
        GLib.Menu menu = new GLib.Menu ();
        generate_undo_actions_section (ref menu);
        if (best_score != 0)
            generate_best_score_section (ref best_score, ref menu);
        menu.freeze ();
        history_button.set_menu_model (menu);
    }

    private static inline void generate_undo_actions_section (ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: during a game, entry in the menu of the history menubutton (with a mnemonic that appears pressing Alt) */
        section.append (_("_Undo"), "ui.undo");

        /* Translators: during a game, entry in the menu of the history menubutton (with a mnemonic that appears pressing Alt) */
        section.append (_("_Restart"), "ui.restart");

        section.freeze ();
        menu.append_section (null, section);
    }

    private static inline void generate_best_score_section (ref uint best_score, ref GLib.Menu menu)
    {
        GLib.Menu section = new GLib.Menu ();

        /* Translators: during a game that has already been finished (and possibly restarted), entry in the menu of the moves button */
        section.append (_("Best score: %u").printf (best_score), null);

        section.freeze ();
        menu.append_section (null, section);
    }
}
