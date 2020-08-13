PREFIX = "usr/local/"
install:
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	install -Dm 755 shrinkwrap_image.sh "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	install -Dm 755 init_image.sh "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
	install -Dm 644 man/init_image.1 "$(DESTDIR)/$(PREFIX)/share/man/init_image.1"
	install -Dm 644 man/shrink_wrap.1 "$(DESTDIR)/$(PREFIX)/share/man/shrink_wrap.1"
	install -Dm 644 man/mount_image.1 "$(DESTDIR)/$(PREFIX)/share/man/mount_image.1"
