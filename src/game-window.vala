/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2015-2016 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

[Flags]
public enum GameWindowFlags {
    SHOW_UNDO,
    SHOW_REDO,
    SHOW_HINT,
    SHOW_START_BUTTON;
}

[GtkTemplate (ui = "/org/gnome/Taquin/ui/game-window.ui")]
public class GameWindow : ApplicationWindow
{
    /* settings */
    private bool tiled_state;
    private bool maximized_state;
    private int window_width;
    private int window_height;

    private bool game_finished = false;

    /* private widgets */
    [GtkChild] private GameHeaderBar    headerbar;
    [GtkChild] private Stack            stack;

    private Button? start_game_button = null;

    [GtkChild] private Box new_game_box;

    private Widget view;

    public GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget _view)
    {
        if (css_resource != null)
        {
            CssProvider css_provider = new CssProvider ();
            css_provider.load_from_resource (css_resource);
            StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        view = _view;

        /* window actions */
        install_win_action_entries ();

        /* window config */
        set_title (name);
        headerbar.set_title (name);

        set_default_size (width, height);
        if (maximized)
            maximize ();

        size_allocate.connect (size_allocate_cb);
        window_state_event.connect (window_state_event_cb);

        /* add widgets */
        new_game_box.pack_start (new_game_screen, true, true, 0);

        if (GameWindowFlags.SHOW_START_BUTTON in flags)
        {
            /* Translators: when configuring a new game, label of the blue Start button (with a mnemonic that appears pressing Alt) */
            start_game_button = new Button.with_mnemonic (_("_Start Game"));
            start_game_button.width_request = 222;
            start_game_button.height_request = 60;
            start_game_button.halign = Align.CENTER;
            start_game_button.set_action_name ("win.start-game");
            /* Translators: when configuring a new game, tooltip text of the blue Start button */
            // start_game_button.set_tooltip_text (_("Start a new game as configured"));
            ((StyleContext) start_game_button.get_style_context ()).add_class ("suggested-action");
            start_game_button.show ();
            new_game_box.pack_end (start_game_button, false, false, 0);
        }

        stack.add (view);
        view.margin = 25;
        view.can_focus = true;
        view.show ();

        headerbar.add_controls (flags);

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    /*\
    * * Window events
    \*/

    private void size_allocate_cb ()
    {
        if (maximized_state || tiled_state)
            return;
        get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            maximized_state = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            tiled_state = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    public void shutdown (GLib.Settings settings)
    {
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", maximized_state);
        destroy ();
    }

    /*\
    * * Some public calls
    \*/

    public void cannot_undo_more ()
    {
        undo_action.set_enabled (false);
        view.grab_focus ();
    }

    public void set_subtitle (string? subtitle)
    {
        headerbar.set_subtitle (subtitle);
    }

    public void finish_game ()
    {
        game_finished = true;
        headerbar.new_game_button_grab_focus ();
    }

    /* public void about ()
    {
        TODO
    } */

    /*\
    * * Showing the Stack
    \*/

    private void show_new_game_screen ()
    {
        bool grabs_focus = headerbar.show_new_game_screen (game_finished);
        if (!grabs_focus && start_game_button != null)
            start_game_button.grab_focus ();
        // TODO else if (!grabs_focus && start_game_button == null)
        stack.set_visible_child (new_game_box);
    }

    private void show_view ()
    {
        stack.set_visible_child (view);
        bool grabs_focus = headerbar.show_view (game_finished);
        if (!grabs_focus)
            view.grab_focus ();
    }

    /*\
    * * actions
    \*/

    public signal void play ();
    public signal void wait ();
    public signal void back ();

    public signal void undo ();
    public signal void redo ();
    public signal void hint ();

    private SimpleAction back_action;
    public  SimpleAction undo_action;
    public  SimpleAction redo_action;

    private void install_win_action_entries ()
    {
        add_action_entries (win_actions, this);

        back_action = (SimpleAction) lookup_action ("back");
        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");

        back_action.set_enabled (false);
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
    }

    private const GLib.ActionEntry win_actions[] =
    {
        { "new-game", new_game_cb },
        { "start-game", start_game_cb },
        { "back", back_cb },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb },

        { "toggle-hamburger", toggle_hamburger }
    };

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "frame")
            return;

        wait ();

        stack.set_transition_type (StackTransitionType.SLIDE_LEFT);
        stack.set_transition_duration (800);

        headerbar.new_game ();
        back_action.set_enabled (true);
        show_new_game_screen ();
    }

    private void start_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "start-box")
            return;

        game_finished = false;

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        play ();        // FIXME lag (see in Taquin…)

        stack.set_transition_type (StackTransitionType.SLIDE_DOWN);
        stack.set_transition_duration (1000);
        show_view ();
    }

    private void back_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "start-box")
            return;

        // TODO change back headerbar subtitle?
        stack.set_transition_type (StackTransitionType.SLIDE_RIGHT);
        stack.set_transition_duration (800);
        show_view ();

        back ();
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "frame")
            return;

        game_finished = false;

        if (headerbar.new_game_button_is_focus ())
            view.grab_focus();
        redo_action.set_enabled (true);

        undo ();
    }

    private void redo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "frame")
            return;

        if (headerbar.new_game_button_is_focus ())
            view.grab_focus();
        undo_action.set_enabled (true);

        redo ();
    }

    private void hint_cb (/* SimpleAction action, Variant? variant */)
    {
        if (stack.get_visible_child_name () != "frame")
            return;

        hint ();
    }

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        headerbar.toggle_hamburger ();
    }
}
