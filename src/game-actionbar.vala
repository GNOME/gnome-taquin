/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of a GNOME game

   Copyright (C) 2019 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

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

[GtkTemplate (ui = "/org/gnome/Taquin/ui/game-actionbar.ui")]
private class GameActionBar : Revealer, AdaptativeWidget
{
    [CCode (notify = false)] public bool show_actionbar  { private get; protected construct set; default = false; }
    [CCode (notify = false)] public bool window_has_name { private get; protected construct set; default = false; }
    [CCode (notify = false)] public string  window_name  { private get; protected construct set; default = ""   ; }
    [CCode (notify = false)] public Widget? game_widget  { private get; protected construct    ; default = null ; }

    [GtkChild] private ActionBar action_bar;
    [GtkChild] private Label game_label;

    construct
    {
        if (game_widget != null)
            action_bar.pack_end ((!) game_widget);

        if (window_has_name)
            game_label.set_label (window_name);

        update_visibility ();
    }

    internal GameActionBar (string _game_name, Widget? _game_widget, bool _show_actionbar)
    {
        Object (window_has_name : _game_name != "",
                window_name     : _game_name,
                game_widget     : _game_widget,
                show_actionbar  : _show_actionbar);
    }

    /*\
    * * adaptative stuff
    \*/

    private bool is_extra_thin = true;
    protected override void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
//        if (game_widget != null)
//            ((AdaptativeWidget) (!) game_widget).set_window_size (new_size);

        bool _is_extra_thin = AdaptativeWidget.WindowSize.is_extra_thin (new_size);
        if (_is_extra_thin == is_extra_thin)
            return;
        is_extra_thin = _is_extra_thin;
        update_visibility ();
    }

    private void update_visibility ()
    {
        set_reveal_child (is_extra_thin && show_actionbar);
    }

    /*\
    * * some internal calls
    \*/

    internal void update_title (string new_title)
    {
        window_name = new_title;
        window_has_name = new_title != "";
        game_label.set_label (window_name);
    }

    internal void set_visibility (bool new_visibility)
    {
        show_actionbar = new_visibility;
        update_visibility ();
    }
}
