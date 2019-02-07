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

private class GameWindow : BaseWindow, AdaptativeWidget
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
    private Box             new_game_screen;

    public GameWindow (string? css_resource, string name, int width, int height, bool maximized, bool start_now, GameWindowFlags flags, Box _new_game_screen, Widget view_content, NightLightMonitor night_light_monitor)
    {
        GameHeaderBar _headerbar = new GameHeaderBar (name, flags, night_light_monitor);
        GameView      _game_view = new GameView (flags, _new_game_screen, view_content);

        Object (nta_headerbar               : (NightTimeAwareHeaderBar) _headerbar,
                base_view                   : (BaseView) _game_view,
                window_title                : Taquin.PROGRAM_NAME,
                specific_css_class_or_empty : "");

        headerbar = _headerbar;
        game_view = _game_view;
        new_game_screen = _new_game_screen;

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

    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        base.set_window_size (new_size);

        ((AdaptativeWidget) new_game_screen).set_window_size (new_size);
        ((AdaptativeWidget) game_view).set_window_size (new_size);
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

    internal void shutdown (GLib.Settings settings)
    {
        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", maximized_state);
        settings.apply ();
        destroy ();
    }

    /*\
    * * Some public calls
    \*/

    internal void move (uint moves_count)
    {
        headerbar.set_moves_count (ref moves_count);
        hide_notification ();
        bool undo_possible = moves_count != 0;
        restart_action.set_enabled (undo_possible);
        undo_action.set_enabled (undo_possible);
        if (!undo_possible)
            game_view.show_game_content (/* grab focus */ true);
    }

    internal void finish_game ()
    {
        game_finished = true;
        headerbar.new_game_button_grab_focus ();
        string best_score_string;
        headerbar.save_best_score (out best_score_string);
        show_notification (best_score_string);
    }

    protected override bool escape_pressed ()
    {
        if (base.escape_pressed ())
            return true;
        if (back_action_disabled)
            return true;
        if (game_view.game_content_visible_if_true ())
            return true;

        // TODO change back headerbar subtitle?
        game_view.configure_transition (StackTransitionType.SLIDE_RIGHT, 800);
        show_view ();

        back ();
        return true;
    }

    /*\
    * * Showing the Stack
    \*/

    private void show_new_game_screen ()
    {
        hide_notification ();
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

    public signal void restart ();
    public signal void undo ();
    public signal void redo ();
    public signal void hint ();

    private SimpleAction restart_action;
    private SimpleAction    undo_action;
    private SimpleAction    redo_action;

    private bool back_action_disabled = true;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

        restart_action = (SimpleAction) action_group.lookup_action ("restart");
           undo_action = (SimpleAction) action_group.lookup_action ("undo");
           redo_action = (SimpleAction) action_group.lookup_action ("redo");

        restart_action.set_enabled (false);
           undo_action.set_enabled (false);
           redo_action.set_enabled (false);
    }

    private const GLib.ActionEntry [] ui_action_entries =
    {
        { "start-or-restart",   start_or_restart_cb },  // "Start new game" button or <Shift><Primary>n
        { "new-game",           new_game_cb },          // "New game" button or <Shift>n
        { "restart",            restart_cb },           // "Restart" menu entry; keep action to allow disabling menu entry

        { "undo", undo_cb },
        { "redo", redo_cb },
        { "hint", hint_cb }
    };

    private void start_or_restart_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;

        if (!game_view.game_content_visible_if_true ())
            start_game ();
        else if (restart_action.get_enabled ())
            restart_game ();
        else
            /* Translator: during a game, if the user tries with <Shift><Ctrl>n to restart the game, while already on initial position */
            show_notification (_("Already on initial position."));
    }

    private void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;
        if (!game_view.game_content_visible_if_true ())
            return;

        new_game ();
    }

    private void restart_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;
        if (!game_view.game_content_visible_if_true ())
            return;

        restart_game ();
    }

    private void undo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;
        if (!game_view.game_content_visible_if_true ())
            return;

        game_finished = false;
        hide_notification ();

        if (headerbar.new_game_button_is_focus ())
            game_view.show_game_content (/* grab focus */ true);
        redo_action.set_enabled (true);

        undo ();
    }

    private void redo_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;
        if (!game_view.game_content_visible_if_true ())
            return;

        if (headerbar.new_game_button_is_focus ())
            game_view.show_game_content (/* grab focus */ true);
        restart_action.set_enabled (true);
        undo_action.set_enabled (true);

        redo ();
    }

    private void hint_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_view.is_in_in_window_mode ())
            return;
        if (!game_view.game_content_visible_if_true ())
            return;

        hint ();
    }

    /*\
    * * actions helpers
    \*/

    private void start_game ()
    {
        game_finished = false;

        restart_action.set_enabled (false);
           undo_action.set_enabled (false);
           redo_action.set_enabled (false);

        play ();        // FIXME lag (see in Taquin…)

        game_view.configure_transition (StackTransitionType.SLIDE_DOWN, 1000);
        show_view ();
    }

    private void restart_game ()
    {
        game_finished = false;
        hide_notification ();

        if (headerbar.new_game_button_is_focus ())
            game_view.show_game_content (/* grab focus */ true);
        redo_action.set_enabled (true);
        restart_action.set_enabled (false);

        restart ();
    }

    private void new_game ()
    {
        wait ();

        game_view.configure_transition (StackTransitionType.SLIDE_LEFT, 800);

        headerbar.new_game ();
        back_action_disabled = false;
        show_new_game_screen ();
    }
}
