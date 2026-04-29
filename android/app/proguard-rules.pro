# libtorrent4j SWIG JNI bridge — the native .so calls these via GetStaticMethodID/GetMethodID.
# R8 cannot see these usages and would strip them, causing NoSuchMethodError at startup.
-keep class org.libtorrent4j.** { *; }
-keep class org.libtorrent4j.swig.** { *; }
