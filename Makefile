PREFIX = "usr/local/"
install:
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	install -Dm 755 shrinkwrap_image.sh "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	install -Dm 755 init_image.sh "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
	install -Dm 644 man/init_image.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/init_image.1"
	install -Dm 644 man/shrink_wrap.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/shrink_wrap.1"
	install -Dm 644 man/mount_image.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/mount_image.1"
	
remove:
	rm "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/init_image.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/shrink_wrap.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/mount_image.1"
