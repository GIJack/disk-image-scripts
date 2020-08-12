PREFIX = "usr/local/"
install:
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/image_shrinkwrap.sh"
