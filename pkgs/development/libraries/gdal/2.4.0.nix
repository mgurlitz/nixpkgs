{ lib, stdenv, fetchurl, fetchpatch, unzip, libjpeg, libtiff, zlib
, postgresql, libmysqlclient, libgeotiff, pythonPackages, proj, geos, openssl
, libpng, sqlite, libspatialite, poppler, hdf4, qhull, giflib, expat
, libiconv, libxml2
, netcdfSupport ? true, netcdf, hdf5, curl
}:

with lib;

stdenv.mkDerivation rec {
  pname = "gdal";
  version = "2.4.0";

  src = fetchurl {
    url = "https://download.osgeo.org/gdal/${version}/${pname}-${version}.tar.xz";
    sha256 = "09qgy36z0jc9w05373m4n0vm4j54almdzql6z9p9zr9pdp61syf3";
  };

  patches = [
    (fetchpatch {
      name = "CVE-2019-17545.patch";
      url = "https://github.com/OSGeo/gdal/commit/8cd2d2eb6327cf782a74dae263ffa6f89f46c93d.patch";
      stripLen = 1;
      sha256 = "06h88a659jcqf6ps1m91qy78s6s9krbkwnz28f5qh7032vlp6qpw";
    })
  ];

  buildInputs = [ unzip libjpeg libtiff libgeotiff libpng proj openssl sqlite
    libspatialite poppler hdf4 qhull giflib expat libxml2 proj ]
  ++ (with pythonPackages; [ python numpy wrapPython ])
  ++ lib.optional stdenv.isDarwin libiconv
  ++ lib.optionals netcdfSupport [ netcdf hdf5 curl ];

  configureFlags = [
    "--with-expat=${expat.dev}"
    "--with-jpeg=${libjpeg.dev}"
    "--with-libtiff=${libtiff.dev}" # optional (without largetiff support)
    "--with-png=${libpng.dev}"      # optional
    "--with-poppler=${poppler.dev}" # optional
    "--with-libz=${zlib.dev}"       # optional
    "--with-pg=${postgresql}/bin/pg_config"
    "--with-mysql=${getDev libmysqlclient}/bin/mysql_config"
    "--with-geotiff=${libgeotiff.dev}"
    "--with-sqlite3=${sqlite.dev}"
    "--with-spatialite=${libspatialite}"
    "--with-python"               # optional
    "--with-proj=${proj.dev}" # optional
    "--with-geos=${geos}/bin/geos-config"# optional
    "--with-hdf4=${hdf4.dev}" # optional
    "--with-xml2=${libxml2.dev}/bin/xml2-config" # optional
    (if netcdfSupport then "--with-netcdf=${netcdf}" else "")
  ];

  hardeningDisable = [ "format" ];

  CXXFLAGS = "-fpermissive";

  postPatch = ''
    sed -i '/ifdef bool/i\
      #ifdef swap\
      #undef swap\
      #endif' ogr/ogrsf_frmts/mysql/ogr_mysql.h
    # poppler 0.73.0 support
    patch -lp2 <${
      fetchpatch {
        url = "https://github.com/OSGeo/gdal/commit/29f4dfbcac2de718043f862166cd639ab578b552.diff";
        sha256 = "1h2rsjjrgwqfgqzppmzv5jgjs1dbbg8pvfmay0j9y0618qp3r734";
      }
    } || true
    patch -p2 <${
      fetchpatch {
        url = "https://github.com/OSGeo/gdal/commit/19967e682738977e11e1d0336e0178882c39cad2.diff";
        sha256 = "12yqd77226i6xvzgqmxiac5ghdinixh8k2crg1r2gnhc0xlc3arj";
      }
    }
  '';

  # - Unset CC and CXX as they confuse libtool.
  # - teach gdal that libdf is the legacy name for libhdf
  preConfigure = ''
      unset CC CXX
      substituteInPlace configure \
      --replace "-lmfhdf -ldf" "-lmfhdf -lhdf"
    '';

  preBuild = ''
    substituteInPlace swig/python/GNUmakefile \
      --replace "ifeq (\$(STD_UNIX_LAYOUT),\"TRUE\")" "ifeq (1,1)"
  '';

  postInstall = ''
    wrapPythonPrograms
  '';

  enableParallelBuilding = true;

  meta = {
    description = "Translator library for raster geospatial data formats";
    homepage = "https://www.gdal.org/";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.marcweber ];
    platforms = with lib.platforms; linux ++ darwin;
  };
}
