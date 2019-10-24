/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of a GNOME game

   Copyright (C) 2015-2016 – Arnaud Bonatti <arnaud.bonatti@gmail.com>

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

[GtkTemplate (ui = "/org/gnome/Taquin/ui/taquin-screens.ui")]
private class NewGameScreen : Box, AdaptativeWidget
{
    /*\
    * * options buttons
    \*/

    [GtkChild] private MenuButton size_button;
    [GtkChild] private MenuButton theme_button;

    internal void update_size_button_label (int size)
    {
        /* Translators: when configuring a new game, button label for the size of the game ("3 × 3", or 4, or 5) */
        size_button.set_label (_("Size: %d × %d ▾").printf (size, size));
     // size_button.set_label (_("Size: %hhu × %hhu ▾").printf (size, size));   // TODO uint8
    }

    internal void update_theme (string theme)
    {
        switch (theme)
        {
            /* Translators: when configuring a new game, button label for the theme, if the current theme is Cats */
            case "cats":    theme_button.set_label (_("Theme: Cats ▾")); break;

            /* Translators: when configuring a new game, button label for the theme, if the current theme is Numbers */
            case "numbers": theme_button.set_label (_("Theme: Numbers ▾")); break;

            default: warn_if_reached (); break;
        }
    }

    /*\
    * * adaptative stuff
    \*/

    construct   // FIXME things are a bit racy between the CSS and the box orientation changes, so delay games_box redraw
    {
        size_allocate.connect_after (() => games_box.show ());
        map.connect (() => games_box.show ());
    }

    [GtkChild] private Box          games_box;
    [GtkChild] private Box          options_box;

    [GtkChild] private Label        games_label;
    [GtkChild] private Label        options_label;
    [GtkChild] private Separator    options_separator;

    private bool phone_size = false;
    private bool extra_thin = false;
    private bool extra_flat = false;
    private void set_window_size (AdaptativeWidget.WindowSize new_size)
    {
        bool _extra_flat = AdaptativeWidget.WindowSize.is_extra_flat (new_size);
        bool _extra_thin = (new_size == AdaptativeWidget.WindowSize.EXTRA_THIN);
        bool _phone_size = (new_size == AdaptativeWidget.WindowSize.PHONE_BOTH)
                        || (new_size == AdaptativeWidget.WindowSize.PHONE_VERT);

        if ((_extra_thin == extra_thin)
         && (_phone_size == phone_size)
         && (_extra_flat == extra_flat))
            return;
        extra_thin = _extra_thin;
        phone_size = _phone_size;
        extra_flat = _extra_flat;

        if (!_extra_thin && !_phone_size)
        {
            if (extra_flat)
            {
                games_label.hide ();
                options_label.hide ();
                this.set_orientation (Orientation.HORIZONTAL);
                games_box.set_orientation (Orientation.VERTICAL);
                options_box.set_orientation (Orientation.VERTICAL);
                options_separator.set_orientation (Orientation.VERTICAL);
                options_separator.show ();
            }
            else
            {
                games_label.hide ();
                options_label.hide ();
                options_separator.hide ();
                this.set_orientation (Orientation.VERTICAL);
                games_box.set_orientation (Orientation.HORIZONTAL);
                options_box.set_orientation (Orientation.HORIZONTAL);
                games_box.hide ();
            }
        }
        else if (_phone_size)
        {
            games_label.hide ();
            options_label.hide ();
            this.set_orientation (Orientation.VERTICAL);
            games_box.set_orientation (Orientation.VERTICAL);
            options_box.set_orientation (Orientation.VERTICAL);
            options_separator.set_orientation (Orientation.HORIZONTAL);
            options_separator.show ();
        }
        else
        {
            options_separator.hide ();
            this.set_orientation (Orientation.VERTICAL);
            games_box.set_orientation (Orientation.VERTICAL);
            options_box.set_orientation (Orientation.VERTICAL);
            games_label.show ();
            options_label.show ();
        }
        queue_allocate ();
    }
}
