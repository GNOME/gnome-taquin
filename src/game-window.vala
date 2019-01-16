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

private class GameWindow : ApplicationWindow
{
    /* settings */
    private bool tiled_state;
    private bool maximized_state;
    private int window_width;
    private int window_height;

    private bool game_finished = false;

    /* private widgets */
    private GameHeaderBar   headerbar;
    private GameView        game_view;

    public GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget view_content)
    {
        headerbar = new GameHeaderBar (flags);
        headerbar.show ();
        game_view = new GameView (flags, new_game_screen, view_content);
        game_view.show ();
        set_titlebar (headerbar);
        add (game_view);

        /* CSS */
        if (css_resource != null)
        {
            CssProvider css_provider = new CssProvider ();
            css_provider.load_from_resource ((!) css_resource);
            Gdk.Screen? gdk_screen = Gdk.Screen.get_default ();
            if (gdk_screen != null) // else..?
                StyleContext.add_provider_for_screen ((!) gdk_screen, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
        }

        /* window actions */
        install_ui_action_entries ();

        /* window config */
        set_title (name);
        headerbar.set_title (name);

        set_default_size (width, height);
        if (maximized)
            maximize ();

        size_allocate.connect (size_allocate_cb);
        window_state_event.connect (window_state_event_cb);

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
        game_view.show_game_content (/* grab focus */ true);
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
        game_view.show_new_game_box (/* grab focus */ !grabs_focus);
    }

    private void show_view ()
    {
        bool grabs_focus = headerbar.show_view (game_finished);
        game_view.show_game_content (/* grab focus */ !grabs_focus);
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

    public SimpleAction undo_action;
    public SimpleAction redo_action;

    private bool back_action_disabled = true;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

        undo_action = (SimpleAction) action_group.lookup_action ("undo");
        redo_action = (SimpleAction) action_group.lookup_action ("redo");

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "new-game", new_game_cb },
        { "start-game", start_game_cb },
        { "escape", escape_pressed },

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb },

        { "toggle-hamburger", toggle_hamburger }
    };

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_view.game_content_visible_if_true ())
            return;

        wait ();

        game_view.configure_transition (StackTransitionType.SLIDE_LEFT, 800);

        headerbar.new_game ();
        back_action_disabled = false;
        show_new_game_screen ();
    }

    private void start_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.game_content_visible_if_true ())
            return;

        game_finished = false;

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);

        play ();        // FIXME lag (see in Taquin…)

        game_view.configure_transition (StackTransitionType.SLIDE_DOWN, 1000);
        show_view ();
    }

    private void escape_pressed (/* SimpleAction action, Variant? variant */)
    {
        if (back_action_disabled)
            return;
        if (game_view.game_content_visible_if_true ())
            return;

        // TODO change back headerbar subtitle?
        game_view.configure_transition (StackTransitionType.SLIDE_RIGHT, 800);
        show_view ();

        back ();
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_view.game_content_visible_if_true ())
            return;

        game_finished = false;

        if (headerbar.new_game_button_is_focus ())
            game_view.show_game_content (/* grab focus */ true);
        redo_action.set_enabled (true);

        undo ();
    }

    private void redo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_view.game_content_visible_if_true ())
            return;

        if (headerbar.new_game_button_is_focus ())
            game_view.show_game_content (/* grab focus */ true);
        undo_action.set_enabled (true);

        redo ();
    }

    private void hint_cb (/* SimpleAction action, Variant? variant */)
    {
        if (!game_view.game_content_visible_if_true ())
            return;

        hint ();
    }

    private void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
        headerbar.toggle_hamburger ();
    }
}
