/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2014 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of Taquin.
 *
 * Taquin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Taquin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with Taquin. If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class Taquin : Gtk.Application
{
    /* Settings */
    private GLib.Settings settings;
    private bool is_fullscreen;
    private bool is_maximized;
    private int window_width;
    private int window_height;
    private static int tmp_size = 0;
    private string tmp_type;
    private bool type_changed = false;
    private bool size_changed = false;
    private bool theme_changed = false;
    private static bool? sound = null;

    /* Widgets */
    private ApplicationWindow window;
    private HeaderBar headerbar;
    private Button back_button;
    private Button undo_button;
    private Button start_game_button;
    private Button start_over_button;
    private Stack stack;
    private MenuButton size_button;
    private MenuButton theme_button;
    private TaquinView view;

    /* The game being played */
    private Game? game = null;
    private SimpleAction undo_action;
    List<string> theme_dirlist;
    private bool game_finished = false;

    private static const OptionEntry[] option_entries =
    {
        { "fifteen", 0, 0, OptionArg.NONE, null, N_("Play the classical 1880s’ 15-puzzle"), null},
        { "sixteen", 0, 0, OptionArg.NONE, null, N_("Try this fun alternative 16-puzzle"), null},
        { "size", 's', 0, OptionArg.INT, ref tmp_size, N_("Sets the puzzle edges’ size (3-5, 2-9 for debug)"), null},
        { "mute", 0, 0, OptionArg.NONE, null, N_("Turn off the sound"), null},
        { "unmute", 0, 0, OptionArg.NONE, null, N_("Turn on the sound"), null},
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null},
        /* { "no-gtk", 0, 0, OptionArg.NONE, null, N_("Begins a console game"), null}, TODO */
        { null }
    };

    private const GLib.ActionEntry app_actions[] =
    {
        {"help", help_cb},
        {"about", about_cb},
        {"quit", quit}
    };
    private const GLib.ActionEntry win_actions[] =
    {
        {"new-game", new_game_cb},
        {"start-game", start_game_cb},
        {"back", back_cb},

        /* {"change-type", null, "s", null, null, change_type_cb},  TODO SimpleActionChangeStateCallback is deprecated...
        {"change-size", null, "s", null, null, change_size_cb},     http://valadoc.org/#!api=gio-2.0/GLib.SimpleActionChangeStateCallback
        {"change-theme", null, "s", null, null, change_theme_cb},   see comments about window.add_action (settings.create_action (…)) */

        {"change-type", change_type_cb, "s"},
        {"change-size", change_size_cb, "s"},
        {"change-theme", change_theme_cb, "s"},

        {"undo", undo_cb}
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Taquin"));

        Window.set_default_icon_name ("gnome-taquin");

        return new Taquin ().run (args);
    }

    public Taquin ()
    {
        Object (application_id: "org.gnome.taquin", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-taquin", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (tmp_size != 0 && tmp_size < 2)
            tmp_size = 2;

        if (options.contains ("unmute"))
            sound = true;
        if (options.contains ("mute"))
            sound = false;

        if (options.contains ("fifteen"))
            tmp_type = "fifteen";
        else if (options.contains ("sixteen"))
            tmp_type = "sixteen";

        return -1;
    }

    protected override void startup()
    {
        base.startup ();

        var css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/taquin/ui/taquin.css");
        StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        settings = new GLib.Settings ("org.gnome.taquin");
        if (sound != null)
            settings.set_boolean ("sound", sound);
        if (tmp_size > 1)
            settings.set_int ("size", tmp_size);
        if (tmp_type != null)
            settings.set_string ("type", tmp_type);

        var builder = new Builder.from_resource ("/org/gnome/taquin/ui/taquin.ui");
        window = builder.get_object ("taquin-window") as ApplicationWindow;
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        add_action_entries (app_actions, this);
        window.add_action_entries (win_actions, this);
        undo_action = (SimpleAction) window.lookup_action ("undo");
        // TODO window.add_action (settings.create_action ("type"));        // Problem: same bug as in Iagno, the settings are resetted to the first radiobutton found
        // TODO window.add_action (settings.create_action ("size"));        // Problem: cannot use this way for an integer from a menu; works for radiobuttons in Iagno
        // TODO window.add_action (settings.create_action ("theme"));       // Problem: a bug that exists in the three tries, and in Iagno: you cannot manually change the gsetting or it bugs completely (gsetting between two states)
        set_accels_for_action ("app.help", {"F1"});
        set_accels_for_action ("app.quit", {"<Primary>q"});
        set_accels_for_action ("win.new-game", {"<Primary>n"});
        set_accels_for_action ("win.undo", {"<Primary>z"});
        add_action (settings.create_action ("sound"));

        headerbar = builder.get_object ("headerbar") as HeaderBar;
        back_button = builder.get_object ("back-button") as Button;
        undo_button = builder.get_object ("undo-button") as Button;
        start_game_button = builder.get_object ("start-game-button") as Button;
        start_over_button = builder.get_object ("start-over-button") as Button;
        stack = builder.get_object ("main-stack") as Stack;

        size_button = builder.get_object ("size-button") as MenuButton;
        settings.changed["size"].connect (() => {
            if (!size_changed)
                update_size_button_label (settings.get_int ("size"));
            size_changed = false;
        });
        update_size_button_label (settings.get_int ("size"));

        theme_button = builder.get_object ("theme-button") as MenuButton;
        settings.changed["theme"].connect (() => {
            if (!theme_changed)
                update_theme (settings.get_string ("theme"));
            theme_changed = false;
        });
        update_theme (settings.get_string ("theme"));

        settings.changed["type"].connect (() => {
            if (!type_changed)
            {
                var button_name = "radio-" + settings.get_string ("type");
                ((RadioButton) builder.get_object (button_name)).set_active (true);
            }
            type_changed = false;
        });
        var button_name = "radio-" + settings.get_string ("type");
        ((RadioButton) builder.get_object (button_name)).set_active (true);

        var game_box = builder.get_object ("game-box") as Box;
        view = new TaquinView ();
        view.halign = Align.FILL;
        view.show ();
        game_box.pack_start (view, true, true, 0);

        add_window (window);
        start_game ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
    }

    /*\
    * * Window events
    \*/

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (is_maximized || is_fullscreen)
            return false;
        window_width = event.width;
        window_height = event.height;
        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
        return false;
    }

    /*\
    * * Switching the Stack
    \*/

    private void new_game_cb ()
    {
        headerbar.set_subtitle (null);
        stack.set_transition_type (StackTransitionType.SLIDE_LEFT);
        stack.set_transition_duration (800);
        undo_button.hide ();
        stack.set_visible_child_name ("start-box");
        back_button.show ();
        if (undo_action.enabled)
            back_button.grab_focus ();
        else
            start_game_button.grab_focus ();
    }

    private void back_cb ()
    {
        stack.set_transition_type (StackTransitionType.SLIDE_RIGHT);
        stack.set_transition_duration (800);
        back_button.hide ();
        stack.set_visible_child_name ("frame");
        undo_button.show ();
        if (game_finished)
            start_over_button.grab_focus ();    // TODO change headerbar subtitle?
        else
            view.grab_focus ();
    }

    private void start_game_cb ()
    {
        stack.set_transition_type (StackTransitionType.SLIDE_DOWN);
        stack.set_transition_duration (1500);
        back_button.hide ();
        start_game ();
        undo_button.show ();
    }

    /*\
    * * Creating and starting game
    \*/

    private void start_game ()
    {
        if (game != null)
            SignalHandler.disconnect_by_func (game, null, this);

        undo_action.set_enabled (false);
        game_finished = false;

        var type = (GameType) settings.get_enum ("type");
        var size = settings.get_int ("size");
        game = new Game (type, size);
        view.game = game;
        view.grab_focus ();

        var filename = "";
        var dirlist = theme_dirlist.copy ();
        do
        {
            var random = Random.int_range (0, (int) dirlist.length());
            filename = dirlist.nth_data(random);
            unowned List<string> entry = dirlist.find_custom (filename, strcmp);
            dirlist.remove_link (entry);
        } while (filename[0] == '0' || (filename[0] != '1' && filename[0] != size.to_string ()[0] && dirlist.length () != 0));
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", settings.get_string ("theme"), filename);

        game.complete.connect (game_complete_cb);
        game.cannot_move.connect (cannot_move_cb);
        game.cannot_undo_more.connect (cannot_undo_more_cb);
        game.move.connect (move_cb);

        stack.set_visible_child_name ("frame"); // FIXME lag…
    }

    /*\
    * * App-menu callbacks
    \*/

    private void about_cb ()
    {
        string[] authors = { "Arnaud Bonatti", null };
        string[] artists = { "Ola Einang (Flickr)",
                             "Ruskis (Wikimedia)",
                             "Alvesgaspar (Wikimedia)",
                             "Mark J. Sebastian (Flickr)",
                             "Mueller-rech.muenchen (Wikimedia)",
                             _("(see COPYING.themes for informations)"),
                             null };
        string[] documenters = { "Arnaud Bonatti", null };
        show_about_dialog (window,
                           "name", _("Taquin"),
                           "version", VERSION,
                           "copyright", "Copyright © 2014 Arnaud Bonatti",
                           "license-type", License.GPL_3_0,
                           "comments", _("A classic 15-puzzle game"),
                           "authors", authors,
                           "artists", artists,
                           "documenters", documenters,
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "gnome-taquin",
                           "website", "https://wiki.gnome.org/Apps/Taquin",
                           null);
    }

    private void help_cb ()
    {
        try
        {
            show_uri (window.get_screen (), "help:gnome-taquin", get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    /*\
    * * Undoing and signals from game
    \*/

    private void undo_cb ()
    {
        game.undo ();
        play_sound ("sliding-1");
    }

    private void cannot_undo_more_cb ()
    {
        undo_action.set_enabled (false);
        view.grab_focus ();
    }
    private void move_cb ()
    {
        headerbar.set_subtitle (null);
        undo_action.set_enabled (true);
        play_sound ("sliding-1");
    }
    private void cannot_move_cb ()
    {
        headerbar.set_subtitle (_("You can’t move this tile!"));
    }
    private void game_complete_cb ()
    {
        game_finished = true;
        start_over_button.grab_focus ();
        headerbar.set_subtitle (_("Bravo! You finished the game!"));
        undo_action.set_enabled (false);
        play_sound ("gameover");
    }

    /*\
    * * Options of the start-screen
    \*/

    private void change_type_cb (SimpleAction action, Variant? variant)
    {
        type_changed = true;
        settings.set_string ("type", variant.get_string ());
    }

    private void change_size_cb (SimpleAction action, Variant? variant)
    {
        size_changed = true;
        var size = int.parse (variant.get_string ());
        update_size_button_label (size);
        settings.set_int ("size", size);
    }
    private void update_size_button_label (int size)
    {
        size_button.set_label (_("Size: %d × %d ▾").printf (size, size));
    }

    private void change_theme_cb (SimpleAction action, Variant? variant)
    {
        theme_changed = true;
        var name = variant.get_string ();
        update_theme (name);
        settings.set_string ("theme", name);
    }
    private void update_theme (string theme)
    {
        switch (theme)
        {
            case "cats":    theme_button.set_label (_("Theme: Cats ▾")); break;
            case "numbers": theme_button.set_label (_("Theme: Numbers ▾")); break;
            default: warn_if_reached (); break;
        }

        Dir dir;
        theme_dirlist = new List<string> ();
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes", theme));
            while (true)
            {
                var filename = dir.read_name ();
                if (filename == null)
                    break;
                theme_dirlist.append (filename);
            }
        }
        catch (FileError e)
        {
            warning ("Failed to load images: %s", e.message);
        }
    }

    /*\
    * * Sound
    \*/

    private void play_sound (string name)
    {
        if (!settings.get_boolean ("sound"))
            return;

        CanberraGtk.play_for_widget (view, 0,
                                     Canberra.PROP_MEDIA_NAME, name,
                                     Canberra.PROP_MEDIA_FILENAME, Path.build_filename (SOUND_DIRECTORY, "%s.ogg".printf (name)));
    }
}
