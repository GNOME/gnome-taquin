/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2014-2016 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

private class Taquin : Gtk.Application, BaseApplication
{
    /* Translators: application name, as used in the window manager, the window title, the about dialog... */
    internal const string PROGRAM_NAME = _("Taquin");

    /* Settings */
    private GLib.Settings settings;
    private static int tmp_size = 0;
    private GameType? tmp_type = null;
    private bool size_changed = false;
    private bool theme_changed = false;
    private static bool? sound = null;

    /* Widgets */
    private GameWindow window;
    private TaquinView view;
    private NewGameScreen new_game_screen;

    /* The game being played */
    private Game? game = null;
    List<string> theme_dirlist;

    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "fifteen", 0, 0,  OptionArg.NONE, null,       N_("Play the classical 1880s’ 15-puzzle"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "sixteen", 0, 0, OptionArg.NONE, null,        N_("Try this fun alternative 16-puzzle"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "size", 's', 0, OptionArg.INT, ref tmp_size,  N_("Sets the puzzle edges’ size (3-5, 2-9 for debug)"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "mute", 0, 0, OptionArg.NONE, null,           N_("Turn off the sound"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "unmute", 0, 0, OptionArg.NONE, null,         N_("Turn on the sound"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
        { "version", 'v', 0, OptionArg.NONE, null,      N_("Print release version and exit"), null},

        /* Translators: command-line option description, see 'gnome-taquin --help' */
     /* { "no-gtk", 0, 0, OptionArg.NONE, null,         N_("Begins a console game"), null}, TODO */
        {}
    };

    private const GLib.ActionEntry [] action_entries =
    {
        /* TODO SimpleActionChangeStateCallback is deprecated...
        {"change-size", null, "s", null, null, change_size_cb},     http://valadoc.org/#!api=gio-2.0/GLib.SimpleActionChangeStateCallback
        {"change-theme", null, "s", null, null, change_theme_cb},   see comments about window.add_action (settings.create_action (…)) */

        {"change-size", change_size_cb, "s"},
        {"change-theme", change_theme_cb, "s"},

        {"set-use-night-mode", set_use_night_mode, "b"},
        {"help", help_cb},
        {"quit", quit}
    };

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
        Window.set_default_icon_name ("org.gnome.Taquin");

        return new Taquin ().run (args);
    }

    private Taquin ()
    {
        Object (application_id: "org.gnome.Taquin", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stdout.printf ("%1$s %2$s\n", "gnome-taquin", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (tmp_size != 0 && tmp_size < 2)
            tmp_size = 2;

        if (options.contains ("mute"))
            sound = false;
        else if (options.contains ("unmute"))
            sound = true;

        if (options.contains ("fifteen"))
            tmp_type = GameType.FIFTEEN;
        else if (options.contains ("sixteen"))
            tmp_type = GameType.SIXTEEN;

        return -1;
    }

    protected override void startup()
    {
        base.startup ();

        settings = new GLib.Settings ("org.gnome.Taquin");
        if (sound != null)
            settings.set_boolean ("sound", (!) sound);
        if (tmp_size > 1)
            settings.set_int ("size", tmp_size);
        if (tmp_type != null)
            settings.set_string ("type", ((!) tmp_type).to_string ());     // TODO better?

        /* UI parts */
        view = new TaquinView ();
        new_game_screen = new NewGameScreen ();

        /* Window */
        init_night_mode ();
        window = new GameWindow ("/org/gnome/Taquin/ui/taquin.css",
                                 PROGRAM_NAME,
                                 settings.get_int ("window-width"),
                                 settings.get_int ("window-height"),
                                 settings.get_boolean ("window-is-maximized"),
                                 true,     // TODO add an option to go to new-game screen?
                                 GameWindowFlags.SHOW_UNDO | GameWindowFlags.SHOW_START_BUTTON,
                                 (Box) new_game_screen,
                                 view,
                                 night_light_monitor);
        window.play.connect (start_game);
        window.undo.connect (undo_cb);

        set_accels_for_action ("base.copy",             {        "<Primary>c"       });
        set_accels_for_action ("base.copy-alt",         { "<Shift><Primary>c"       });
        set_accels_for_action ("ui.new-game",           {        "<Primary>n"       });
        set_accels_for_action ("ui.start-game",         { "<Shift><Primary>n"       });
        set_accels_for_action ("app.quit",              {        "<Primary>q",
                                                          "<Shift><Primary>q"       });
        set_accels_for_action ("base.paste",            {        "<Primary>v"       });
        set_accels_for_action ("base.paste-alt",        { "<Shift><Primary>v"       });
        set_accels_for_action ("ui.undo",               {        "<Primary>z"       });
        set_accels_for_action ("ui.redo",               { "<Shift><Primary>z"       });
        set_accels_for_action ("base.escape",           {                 "Escape"  });
        set_accels_for_action ("base.toggle-hamburger", {                 "F10",
                                                                          "Menu"    });
        set_accels_for_action ("app.help",              {                 "F1"      });

        /* New-game screen signals */
        settings.changed ["size"].connect (() => {
            if (!size_changed)
                new_game_screen.update_size_button_label (settings.get_int ("size"));
            size_changed = false;
        });
        new_game_screen.update_size_button_label (settings.get_int ("size"));

        settings.changed ["theme"].connect (() => {
            if (!theme_changed)
                update_theme (settings.get_string ("theme"));
            theme_changed = false;
        });
        update_theme (settings.get_string ("theme"));

        add_action_entries (action_entries, this);
        add_action (settings.create_action ("sound"));
        add_action (settings.create_action ("type"));        // TODO window action?
        // TODO window.add_action (settings.create_action ("size"));        // Problem: cannot use this way for an integer from a menu; works for radiobuttons in Iagno
        // TODO window.add_action (settings.create_action ("theme"));

        add_window (window);
        start_game ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        window.shutdown (settings);
        base.shutdown ();
    }

    /*\
    * * Night mode
    \*/

    NightLightMonitor night_light_monitor;  // keep it here or it is unrefed

    private void init_night_mode ()
    {
        night_light_monitor = new NightLightMonitor ("/org/gnome/taquin/");
    }

    private void set_use_night_mode (SimpleAction action, Variant? gvariant)
        requires (gvariant != null)
    {
        night_light_monitor.set_use_night_mode (((!) gvariant).get_boolean ());
    }

    /*\
    * * Creating and starting game
    \*/

    private void start_game ()
    {
        if (game != null)
            SignalHandler.disconnect_by_func ((!) game, null, this);

        GameType type = (GameType) settings.get_enum ("type");
        int size = settings.get_int ("size");
        game = new Game (type, size);
        view.game = (!) game;

        string filename = "";
        var dirlist = theme_dirlist.copy ();
        do
        {
            int random = Random.int_range (0, (int) dirlist.length());
            filename = dirlist.nth_data(random);
            unowned List<weak string> entry = dirlist.find_custom (filename, strcmp);
            dirlist.remove_link (entry);
        } while (filename[0] == '0' || (filename[0] != '1' && filename[0] != size.to_string ()[0] && dirlist.length () != 0));
        view.theme = Path.build_filename (DATA_DIRECTORY, "themes", settings.get_string ("theme"), filename);
        view.realize ();        // TODO does that help?

        ((!) game).complete.connect (game_complete_cb);
        ((!) game).cannot_move.connect (cannot_move_cb);
        ((!) game).cannot_undo_more.connect (window.cannot_undo_more);
        ((!) game).move.connect (move_cb);
    }

    /*\
    * * App-menu callbacks
    \*/

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
    * * Signals from window
    \*/

    private void undo_cb ()
        requires (game != null)
    {
        ((!) game).undo ();
        play_sound ("sliding-1");
    }

    /*\
    * * Signals from game
    \*/

    private void move_cb ()
    {
        window.set_subtitle (null);
        window.undo_action.set_enabled (true);
        play_sound ("sliding-1");       // TODO sliding-n??
    }

    private void cannot_move_cb ()
    {
        /* Translators: notification, as a subtitle of the headerbar; on the 15-Puzzle game, if the user clicks a tile that cannot move */
        window.set_subtitle (_("You can’t move this tile!"));
    }

    private void game_complete_cb ()
    {
        window.finish_game ();
        /* Translators: notification, as a subtitle of the headerbar; on both games, if the user solves the puzzle */
        window.set_subtitle (_("Bravo! You finished the game!"));
        window.undo_action.set_enabled (false);    // Taquin specific
        play_sound ("gameover");
    }

    /*\
    * * Options of the start-screen
    \*/

    private void change_size_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        size_changed = true;
        int size = int.parse (((!) variant).get_string ());
        new_game_screen.update_size_button_label (size);
        settings.set_int ("size", size);
    }

    private void change_theme_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        theme_changed = true;
        string name = ((!) variant).get_string ();
        update_theme (name);
        settings.set_string ("theme", name);
    }
    private void update_theme (string theme)
    {
        new_game_screen.update_theme (theme);

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
                theme_dirlist.append ((!) filename);
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

    /*\
    * * Copy action
    \*/

    internal void copy (string text)
    {
        Gdk.Display? display = Gdk.Display.get_default ();
        if (display == null)
            return;

        Gtk.Clipboard clipboard = Gtk.Clipboard.get_default ((!) display);
        clipboard.set_text (text, text.length);
    }

    /*\
    * * about dialog infos
    \*/

    internal void get_about_dialog_infos (out string [] artists,
                                          out string [] authors,
                                          out string    comments,
                                          out string    copyright,
                                          out string [] documenters,
                                          out string    logo_icon_name,
                                          out string    program_name,
                                          out string    translator_credits,
                                          out string    version,
                                          out string    website,
                                          out string    website_label)
    {
        /* Translators: about dialog text */
        comments = _("A classic 15-puzzle game");

        artists = {
            "Abelard (Wikimedia)",
            "Alvesgaspar (Wikimedia)",
            "Mueller-rech.muenchen (Wikimedia)",
            "Ruskis (Wikimedia)",
            "Toyah (Wikimedia)",
            /* Translators: about dialog text; in the Credits, text at the end of the "Artwork by" section */
            _("(see COPYING.themes for informations)")
        };
        authors = { "Arnaud Bonatti" };

        /* Translators: about dialog text */
        copyright = "Copyright \xc2\xa9 2014-2019 – Arnaud Bonatti";  // TODO translation; autogen, to not change each year?
        documenters = { "Arnaud Bonatti" };
        logo_icon_name = "gnome-taquin";
        program_name = Taquin.PROGRAM_NAME;

        /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
        translator_credits = _("translator-credits");
        version = VERSION;

        website = "https://wiki.gnome.org/Apps/Taquin";
        /* Translators: about dialog text; label of the website link */
        website_label = _("Page on GNOME wiki");
    }
}
