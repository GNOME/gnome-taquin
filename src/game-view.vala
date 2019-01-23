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

private class GameView : BaseView, AdaptativeWidget
{
    private Stack           game_stack;
    private Widget          game_content;
    private ScrolledWindow  scrolled;
    private Box             new_game_box;
    private Button?         start_game_button = null;

    construct
    {
        game_stack = new Stack ();
        game_stack.hexpand = true;
        game_stack.vexpand = true;
        game_stack.show ();
        main_grid.add (game_stack);

        scrolled = new ScrolledWindow (null, null);
        scrolled.visible = true;
        game_stack.add (scrolled);

        new_game_box = new Box (Orientation.VERTICAL, /* spacing */ 0);
        new_game_box.halign = Align.CENTER;
        new_game_box.valign = Align.CENTER;
        new_game_box.show ();
        scrolled.add (new_game_box);
    }

    internal GameView (GameWindowFlags flags, Box new_game_screen, Widget content)
    {
        new_game_box.pack_start (new_game_screen, true, true, 0);

        if (GameWindowFlags.SHOW_START_BUTTON in flags)
        {
            /* Translators: when configuring a new game, label of the blue Start button (with a mnemonic that appears pressing Alt) */
            start_game_button = new Button.with_mnemonic (_("_Start Game"));
            ((!) start_game_button).get_style_context ().add_class ("start-game-button");
            ((!) start_game_button).halign = Align.CENTER;
            ((!) start_game_button).set_action_name ("ui.start-or-restart");
            /* Translators: when configuring a new game, tooltip text of the blue Start button */
            // start_game_button.set_tooltip_text (_("Start a new game as configured"));
            ((StyleContext) ((!) start_game_button).get_style_context ()).add_class ("suggested-action");
            ((!) start_game_button).show ();
            new_game_box.pack_end ((!) start_game_button, false, false, 0);
        }

        game_content = content;
        game_stack.add (content);
        update_game_content_margin (short_margin, ref game_content);
        content.can_focus = true;
        content.show ();
    }

    private bool short_margin = false;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        base.set_window_size (new_size);

        bool _short_margin = AdaptativeWidget.WindowSize.is_extra_thin (new_size)
                          || AdaptativeWidget.WindowSize.is_extra_flat (new_size);
        if (_short_margin == short_margin)
            return;
        short_margin = _short_margin;
        update_game_content_margin (short_margin, ref game_content);
    }
    private static void update_game_content_margin (bool new_state, ref Widget game_content)
    {
        if (new_state)
            game_content.margin = 11;
        else
            game_content.margin = 25;
    }

    internal void show_new_game_box (bool grab_focus)
    {
        game_stack.set_visible_child (scrolled);
        if (grab_focus && start_game_button != null)
            ((!) start_game_button).grab_focus ();
        // TODO else if (grab_focus && start_game_button == null)
    }

    internal void show_game_content (bool grab_focus)
    {
        game_stack.set_visible_child (game_content);
        if (grab_focus)
            game_content.grab_focus ();
    }

    internal bool game_content_visible_if_true ()
    {
        return game_stack.get_visible_child () == game_content;
    }

    internal void configure_transition (StackTransitionType transition_type,
                                        uint                transition_duration)
    {
        game_stack.set_transition_type (transition_type);
        game_stack.set_transition_duration (transition_duration);
    }
}
