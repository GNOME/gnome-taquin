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

[GtkTemplate (ui = "/org/gnome/Taquin/ui/new-game-screen.ui")]
private class NewGameScreen : Box, AdaptativeWidget
{
    [GtkChild] private ToggleButton gamebutton_one;
    [GtkChild] private ToggleButton gamebutton_two;

    [GtkChild] private Gtk.MenuButton menubutton_one;
    [GtkChild] private Gtk.MenuButton menubutton_two;

    construct
    {
        CssProvider css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/Taquin/ui/new-game-screen.css");
        Gdk.Display? gdk_display = Gdk.Display.get_default ();
        if (gdk_display != null) // else..?
            StyleContext.add_provider_for_display ((!) gdk_display, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        Widget? widget = menubutton_one.get_first_child ();
        if (widget != null && (!) widget is ToggleButton)
            ((!) widget).get_style_context ().add_class ("flat");
        widget = menubutton_two.get_first_child ();
        if (widget != null && (!) widget is ToggleButton)
            ((!) widget).get_style_context ().add_class ("flat");
    }

    internal NewGameScreen (string gamebutton_one_label,
                            string gamebutton_one_action,
                            string gamebutton_two_label,
                            string gamebutton_two_action)
    {
        gamebutton_one.label = gamebutton_one_label;
        gamebutton_two.label = gamebutton_two_label;

        gamebutton_one.set_detailed_action_name (gamebutton_one_action);
        gamebutton_two.set_detailed_action_name (gamebutton_two_action);
    }

    /*\
    * * options buttons
    \*/

    public enum MenuButton {
        ONE,
        TWO;
    }

    internal inline void update_menubutton_label (MenuButton button, string label)
    {
        Widget? widget;
        switch (button)
        {
            case MenuButton.ONE:
                menubutton_one.set_label (label);
                widget = menubutton_one.get_first_child ();
                if (widget != null && (!) widget is ToggleButton)
                {
                    widget = ((!) widget).get_first_child ();
                    if (widget != null && (!) widget is Box)
                        ((!) widget).halign = Align.CENTER;
                }
                return;

            case MenuButton.TWO: menubutton_two.set_label (label);
                widget = menubutton_two.get_first_child ();
                if (widget != null && (!) widget is ToggleButton)
                {
                    widget = ((!) widget).get_first_child ();
                    if (widget != null && (!) widget is Box)
                        ((!) widget).halign = Align.CENTER;
                }
                return;
        }
    }

    internal inline void update_menubutton_menu (MenuButton button, GLib.Menu menu)
    {
        switch (button)
        {
            case MenuButton.ONE: menubutton_one.set_menu_model (menu); return;
            case MenuButton.TWO: menubutton_two.set_menu_model (menu); return;
        }
    }

    internal inline void update_menubutton_sensitivity (MenuButton button, bool new_sensitivity)
    {
        switch (button)
        {
            case MenuButton.ONE: menubutton_one.set_sensitive (new_sensitivity); return;
            case MenuButton.TWO: menubutton_two.set_sensitive (new_sensitivity); return;
        }
    }

    // that is a quite usual menubutton label, so put it here
    internal static inline string get_size_button_label (int size)
    {
        /* Translators: when configuring a new game, button label for the size of the game ("3 × 3", or 4, or 5) */
        return _("Size: %d × %d ▾").printf (size, size);
     // return _("Size: %hhu × %hhu ▾").printf (size, size));   // TODO uint8
    }

    /*\
    * * adaptative stuff
    \*/

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
