// ASI: libintl stubs for EDB's static libpq on Windows.
//
// EDB builds libpq with NLS, so libpq.a calls three GNU gettext (libintl)
// functions to translate its messages. pqxx.dll links libpq.a statically;
// these stubs return the untranslated message, so WinGLUE ships neither
// libintl-9.dll nor the libiconv-2.dll it pulls in. libpq's own messages
// stay English.

extern "C" {

char *libintl_bindtextdomain(char const * /*domainname*/, char const *dirname)
{
  return const_cast<char *>(dirname);
}

char *libintl_dgettext(char const * /*domainname*/, char const *msgid)
{
  return const_cast<char *>(msgid);
}

char *libintl_dngettext(
  char const * /*domainname*/, char const *msgid, char const *msgid_plural,
  unsigned long n)
{
  return const_cast<char *>(n == 1 ? msgid : msgid_plural);
}

} // extern "C"
