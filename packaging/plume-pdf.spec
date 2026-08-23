%{!?app_version:%global app_version 0.0.16}
%{!?app_release:%global app_release 17}

Name:           plume-pdf
Version:        %{app_version}
Release:        %{app_release}%{?dist}
Summary:        Plume PDF desktop PDF reader
License:        Proprietary
URL:            https://github.com/xiehanff/plume-pdf
Source0:        plume-pdf-bundle.tar.gz
Source1:        plume-pdf-icons.tar.gz
Source2:        com.example.plume_pdf.desktop

BuildArch:      x86_64
BuildRequires:  patchelf
Requires:       gtk3
Requires:       glib2
Requires:       libstdc++

%description
Plume PDF is a Flutter desktop PDF reader with local reading tools and
optional DeepSeek / SiliconFlow AI assistance.

%prep

%build

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/plume-pdf
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons

tar -xzf %{SOURCE0} -C %{buildroot}/opt/plume-pdf --strip-components=1
tar -xzf %{SOURCE1} -C %{buildroot}/usr/share/icons

# Flutter's Linux bundle can contain build-machine RUNPATH entries. Replace
# them with paths that remain valid after installation under /opt/plume-pdf.
patchelf --set-rpath '$ORIGIN/lib' %{buildroot}/opt/plume-pdf/plume_pdf
find %{buildroot}/opt/plume-pdf/lib -type f -name '*.so*' \
  -exec patchelf --set-rpath '$ORIGIN' {} +

# Desktop integration is installed in the standard system locations below.
rm -rf %{buildroot}/opt/plume-pdf/share
sed 's|^Exec=plume_pdf$|Exec=/opt/plume-pdf/plume_pdf|' %{SOURCE2} > \
  %{buildroot}/usr/share/applications/com.example.plume_pdf.desktop

%post
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || :
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
fi

%postun
if [ "$1" -eq 0 ]; then
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || :
  fi
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
  fi
fi

%files
/opt/plume-pdf
%dir /usr/share/applications
/usr/share/applications/com.example.plume_pdf.desktop
/usr/share/icons/hicolor

%changelog
* Sun Aug 16 2026 xiehan <xiehan@users.noreply.github.com> - 0.0.13-11
- Restore macOS title-bar double-click maximize/restore behavior.

* Sun Aug 16 2026 xiehan <xiehan@users.noreply.github.com> - 0.0.12-10
- Remove title-bar button click latency while preserving double-click maximize.
- Add the Debian release packaging workflow.
