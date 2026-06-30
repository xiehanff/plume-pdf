#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

#ifndef NDEBUG
static void copy_file_overwrite(const gchar* source_path,
                                const gchar* target_path) {
  g_autoptr(GError) error = nullptr;
  g_autofree gchar* target_dir = g_path_get_dirname(target_path);
  g_mkdir_with_parents(target_dir, 0755);

  g_autoptr(GFile) source = g_file_new_for_path(source_path);
  g_autoptr(GFile) target = g_file_new_for_path(target_path);
  g_file_copy(source, target, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr,
              &error);
  if (error != nullptr) {
    g_warning("Failed to copy %s to %s: %s", source_path, target_path,
              error->message);
  }
}

static void install_dev_desktop_entry(const gchar* exe_path,
                                      const gchar* icon_path) {
  const gchar* user_data_dir = g_get_user_data_dir();
  g_autofree gchar* applications_dir =
      g_build_filename(user_data_dir, "applications", nullptr);
  g_autofree gchar* desktop_path = g_build_filename(
      applications_dir, "com.example.plume_pdf.desktop", nullptr);

  g_autofree gchar* desktop_contents = g_strdup_printf(
      "[Desktop Entry]\n"
      "Type=Application\n"
      "Name=Plume PDF\n"
      "Exec=%s %%U\n"
      "Icon=%s\n"
      "Terminal=false\n"
      "Categories=Office;Viewer;\n"
      "StartupNotify=true\n"
      "StartupWMClass=com.example.plume_pdf\n"
      "X-GNOME-WMClass=com.example.plume_pdf\n",
      exe_path, icon_path);

  g_mkdir_with_parents(applications_dir, 0755);
  g_file_set_contents(desktop_path, desktop_contents, -1, nullptr);
}
#endif

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "plume_pdf");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));

    // Keep in sync with AppColors.scaffoldBg in lib/app/theme/app_colors.dart.
    GtkCssProvider* css_provider = gtk_css_provider_new();
    gtk_css_provider_load_from_data(css_provider,
        "headerbar {"
        "  background-color: #262A37;"
        "  color: #ffffff;"
        "}",
        -1, NULL);
    gtk_style_context_add_provider(
        gtk_widget_get_style_context(GTK_WIDGET(header_bar)),
        GTK_STYLE_PROVIDER(css_provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
    g_object_unref(css_provider);
  } else {
    gtk_window_set_title(window, "plume_pdf");
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  // Set window icon from bundled assets (works without system-installed icons).
  // fl_dart_project_get_assets_path returns <exe_dir>/data/flutter_assets,
  // the icon is installed to <exe_dir>/data/app_icon_256.png via CMake.
  const gchar* assets_dir = fl_dart_project_get_assets_path(project);
  g_autofree gchar* data_dir = g_path_get_dirname(assets_dir);
  g_autofree gchar* icon_path = g_build_filename(data_dir, "app_icon_256.png", NULL);
  gtk_window_set_icon_from_file(window, icon_path, NULL);
  // Fallback: icon name from .desktop file (works when system-installed).
  gtk_window_set_icon_name(window, APPLICATION_ID);

#ifndef NDEBUG
  // Make `flutter run` visible in the dock by registering a local desktop entry.
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", NULL);
  if (exe_path != nullptr) {
    const gchar* user_data_dir = g_get_user_data_dir();
    g_autofree gchar* icon_dir = g_build_filename(
        user_data_dir, "icons", "hicolor", "256x256", "apps", nullptr);
    g_autofree gchar* user_icon_path = g_build_filename(
        icon_dir, "com.example.plume_pdf.png", nullptr);
    copy_file_overwrite(icon_path, user_icon_path);
    install_dev_desktop_entry(exe_path, user_icon_path);
  }
#endif

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
