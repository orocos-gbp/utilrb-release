Name:           @(Package)
Version:        @(Version)
Release:        @(RPMInc)%{?dist}
Summary:        ROS @(Name) package

Group:          Development/Libraries
License:        @(License)
@[if Homepage and Homepage != '']URL:            @(Homepage)@\n@[end if]Source0:        %{name}-%{version}.tar.gz
@[if NoArch]@\nBuildArch:      noarch@\n@[end if]
@[for p in Depends]Requires:       @p@\n@[end for]@[for p in BuildDepends]BuildRequires:  @p@\n@[end for]@[for p in Conflicts]Conflicts:      @p@\n@[end for]@[for p in Replaces]Obsoletes:      @p@\n@[end for]
%description
@(Description)

%prep
%setup -q

%build
# In case we're installing to a non-standard location, look for a setup.sh
# in the install tree that was dropped by catkin, and source it.  It will
# set things like CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, and PYTHONPATH.
if [ -f "@(InstallationPrefix)/setup.sh" ]; then . "@(InstallationPrefix)/setup.sh"; fi
mkdir -p obj-%{_target_platform} && cd obj-%{_target_platform}
%cmake .. \
        -UINCLUDE_INSTALL_DIR \
        -ULIB_INSTALL_DIR \
        -USYSCONF_INSTALL_DIR \
        -USHARE_INSTALL_PREFIX \
        -ULIB_SUFFIX \
        -DCMAKE_INSTALL_PREFIX="@(InstallationPrefix)" \
        -DCMAKE_PREFIX_PATH="@(InstallationPrefix)" \
        -DSETUPTOOLS_DEB_LAYOUT=OFF \
        -DCATKIN_BUILD_BINARY_PACKAGE="1" \

make %{?_smp_mflags}

%install
# In case we're installing to a non-standard location, look for a setup.sh
# in the install tree that was dropped by catkin, and source it.  It will
# set things like CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, and PYTHONPATH.
if [ -f "@(InstallationPrefix)/setup.sh" ]; then . "@(InstallationPrefix)/setup.sh"; fi
cd obj-%{_target_platform}
make %{?_smp_mflags} install DESTDIR=%{buildroot}

%files
@(InstallationPrefix)
%{_datadir}/ruby/utilrb.rb
%{_datadir}/ruby/utilrb

%changelog@[for change_version, (change_date, main_name, main_email) in changelogs]@\n* @(change_date) @(main_name) <@(main_email)> - @(change_version)@\n- Autogenerated by Bloom@\n@[end for]
