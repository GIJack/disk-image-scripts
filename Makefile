PREFIX = "usr/local/"
install:
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	install -Dm 755 shrinkwrap_image.sh "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	install -Dm 755 init_image.sh "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
