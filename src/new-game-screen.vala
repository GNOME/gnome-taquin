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

[GtkTemplate (ui = "/org/gnome/Taquin/ui/taquin-screens.ui")]
private class NewGameScreen : Box
{
    [GtkChild] private MenuButton size_button;
    [GtkChild] private MenuButton theme_button;

    public void update_size_button_label (int size)
    {
        /* Translators: when configuring a new game, button label for the size of the game ("3 × 3", or 4, or 5) */
        size_button.set_label (_("Size: %d × %d ▾").printf (size, size));
    }

    public void update_theme (string theme)
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
}
