/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of a GNOME game

   Copyright (C) 2015-2019 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

   This application is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this application.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;

[Flags]
private enum GameWindowFlags {
    HAS_SOUND,
    SHORTCUTS,
    SHOW_HELP,
    SHOW_START_BUTTON;
}

private class GameWindow : BaseWindow, AdaptativeWidget
{
    private bool game_finished = false;

    /* private widgets */
    private GameHeaderBar   headerbar;
    private GameView        game_view;
    private GameActionBar   actionbar;

    internal GameWindow (string? css_resource, string name, string about_action_label, bool start_now, GameWindowFlags flags, Box new_game_screen, Widget view_content, GLib.Menu? appearance_menu, Widget? game_widget_1, Widget? game_widget_2, NightLightMonitor night_light_monitor)
    {
        GameActionBar _actionbar = new GameActionBar (name, game_widget_2, /* show actionbar */ start_now);
        GameActionBarPlaceHolder actionbar_placeholder = new GameActionBarPlaceHolder (_actionbar);

        GameHeaderBar _headerbar = new GameHeaderBar (name, about_action_label, flags, appearance_menu, game_widget_1, night_light_monitor);
        GameView      _game_view = new GameView (flags, new_game_screen, view_content, actionbar_placeholder);

        Object (nta_headerbar               : (NightTimeAwareHeaderBar) _headerbar,
                base_view                   : (BaseView) _game_view,
                window_title                : Taquin.PROGRAM_NAME,
                specific_css_class_or_empty : "",
                help_string_or_empty        : "help:gnome-taquin",
                schema_path                 : "/org/gnome/taquin/");

        headerbar = _headerbar;
        game_view = _game_view;
        actionbar = _actionbar;

        add_to_main_overlay (actionbar);
        actionbar.valign = Align.END;

        add_adaptative_child ((AdaptativeWidget) new_game_screen);
        add_adaptative_child ((AdaptativeWidget) game_view);
        add_adaptative_child ((AdaptativeWidget) actionbar);
        add_adaptative_child ((AdaptativeWidget) actionbar_placeholder);

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

        /* start or not */
        if (start_now)
            show_view ();
        else
            show_new_game_screen ();
    }

    /*\
    * * adaptative stuff
    \*/

    private bool is_quite_thin = false;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        base.set_window_size (new_size);

        is_quite_thin = AdaptativeWidget.WindowSize.is_quite_thin (new_size);
    }

    /*\
    * * some public calls
    \*/

    internal void move_done (uint moves_count)
    {
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
    }

    protected override bool escape_pressed ()
    {
        if (base.escape_pressed ())
            return true;
        if (back_action_disabled)
            return true;
        back_cb ();
        return true;
    }
    private void back_cb ()
    {
        if (game_view.game_content_visible_if_true ())
            return;

        // TODO change back headerbar subtitle?
        game_view.configure_transition (StackTransitionType.SLIDE_RIGHT, 800);
        show_view ();

        back ();
    }

    internal void update_title (string game_name)
    {
        headerbar.update_title (game_name);
        actionbar.update_title (game_name);
        actionbar.set_visibility (true);
    }

    /*\
    * * showing the stack
    \*/

    private void show_new_game_screen ()
    {
        hide_notification ();
        headerbar.update_title (Taquin.PROGRAM_NAME);
        actionbar.set_visibility (false);
        bool grabs_focus = headerbar.show_new_game_screen (game_finished);
        game_view.show_new_game_box (/* grab focus */ !grabs_focus);
    }

    private void show_view ()
    {
        bool grabs_focus = headerbar.show_view (game_finished);
        game_view.show_game_content (/* grab focus */ !grabs_focus);
        escape_action.set_enabled (false);
    }

    /*\
    * * actions
    \*/

    internal signal void play ();
    internal signal void wait ();
    internal signal void back ();

    internal signal void restart ();
    internal signal void undo ();
    internal signal void redo ();
    internal signal void hint ();

    private SimpleAction restart_action;
    private SimpleAction    undo_action;
    private SimpleAction    redo_action;
 // private SimpleAction    hint_action;

    private bool back_action_disabled = true;

    private void install_ui_action_entries ()
    {
        SimpleActionGroup action_group = new SimpleActionGroup ();
        action_group.add_action_entries (ui_action_entries, this);
        insert_action_group ("ui", action_group);

        restart_action = (SimpleAction) action_group.lookup_action ("restart");
           undo_action = (SimpleAction) action_group.lookup_action ("undo");
           redo_action = (SimpleAction) action_group.lookup_action ("redo");
     //    hint_action = (SimpleAction) action_group.lookup_action ("hint");

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
        {
            if (!back_action_disabled)
                back_cb ();     // FIXME not reached if undo_action is disabled, so at game start or finish
            return;
        }

        game_finished = false;

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

        if (is_quite_thin)
            game_view.configure_transition (StackTransitionType.SLIDE_DOWN, 1000);
        else
            game_view.configure_transition (StackTransitionType.OVER_DOWN_UP, 1000);

        play ();        // FIXME lag (see in Taquin…)

        show_view ();
    }

    private void restart_game ()
    {
        game_finished = false;
        hide_notification ();

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
        escape_action.set_enabled (true);
        show_new_game_screen ();
    }
}
