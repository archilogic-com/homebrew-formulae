class BoostPythonAT165 < Formula
  desc "C++ library for C++/Python interoperability"
  homepage "https://www.boost.org/"
  url "https://dl.bintray.com/boostorg/release/1.65.0/source/boost_1_65_0.tar.bz2"
  sha256 "ea26712742e2fb079c2a566a31f3266973b76e38222b9f88b387e3c8b2f9902c"
  head "https://github.com/boostorg/boost.git"

  bottle do
    cellar :any
    sha256 "3afa6f99271e3464e93f19f3b580d212b9adec2b0a96bb16b334d073a6eccd80" => :sierra
    sha256 "c865fdca752e3f9ec7db7de3b3df9304bf8a94a0c447191771b6117938588c29" => :el_capitan
    sha256 "1c7ed19d481568b5fb8aacff6541ba31d0a6d96bbfe0b1ca828a8a8bf129411d" => :yosemite
  end

  option "without-python@2", "Build without python 2 support"

  deprecated_option "with-python3" => "with-python"
  deprecated_option "without-python" => "without-python@2"

  depends_on "python@2" => :recommended
  depends_on "python" => :optional

  depends_on "archilogic-com/homebrew-formulae/boost@1.65"

  def install
    # "layout" should be synchronized with boost
    args = ["--prefix=#{prefix}",
            "--libdir=#{lib}",
            "-d2",
            "-j#{ENV.make_jobs}",
            "--layout=tagged",
            "--user-config=user-config.jam",
            "threading=multi,single",
            "link=shared,static"]

    # Build in C++11 mode if boost was built in C++11 mode.
    # Trunk starts using "clang++ -x c" to select C compiler which breaks C++11
    # handling using ENV.cxx11. Using "cxxflags" and "linkflags" still works.
      args << "cxxflags=-std=c++11"
      if ENV.compiler == :clang
        args << "cxxflags=-stdlib=libc++" << "linkflags=-stdlib=libc++"
      end

    # disable python detection in bootstrap.sh; it guesses the wrong include directory
    # for Python 3 headers, so we configure python manually in user-config.jam below.
    inreplace "bootstrap.sh", "using python", "#using python"

    Language::Python.each_python(build) do |python, version|
      print "Using #{python}\n"
      py_prefix = `#{python} -c "from __future__ import print_function; import sys; print(sys.prefix)"`.strip
      py_include = `#{python} -c "from __future__ import print_function; import distutils.sysconfig; print(distutils.sysconfig.get_python_inc(True))"`.strip
      print "Python prefix: " + py_prefix + "\n"
      print "Python include: " + py_include + "\n"
      open("user-config.jam", "w") do |file|
        # Force boost to compile with the desired compiler
        file.write "using darwin : : #{ENV.cxx} ;\n"
        file.write <<~EOS
          using python : #{version}
                       : #{python}
                       : #{py_include}
                       : #{py_prefix}/lib ;
        EOS
      end

      system "./bootstrap.sh", "--prefix=#{prefix}", "--libdir=#{lib}", "--with-libraries=python",
                               "--with-python=#{python}", "--with-python-root=#{py_prefix}"

      system "./b2", "--build-dir=build-#{python}", "--stagedir=stage-#{python}",
                     "python=#{version}", *args
    end

    lib.install Dir["stage-python3/lib/*py*"] if build.with?("python")
    lib.install Dir["stage-python2.7/lib/*py*"] if build.with?("python@2")
    doc.install Dir["libs/python/doc/*"]
  end

  test do
    (testpath/"hello.cpp").write <<-EOS.undent
      #include <boost/python.hpp>
      char const* greet() {
        return "Hello, world!";
      }
      BOOST_PYTHON_MODULE(hello)
      {
        boost::python::def("greet", greet);
      }
    EOS
    Language::Python.each_python(build) do |python, _|
      boost_python = (python == "python3") ? "boost_python3" : "boost_python"
      pyflags = `#{python}-config --includes`.strip.split(" ") +
                `#{python}-config --ldflags`.strip.split(" ")
      system ENV.cxx, "-shared", "hello.cpp", "-I#{Formula["boost165"].opt_include}",
                      "-L#{lib}", "-l#{boost_python}", "-o", "hello.so", *pyflags
      output = `#{python} -c "from __future__ import print_function; import hello; print(hello.greet())"`
      assert_match "Hello, world!", output
    end
  end
end
