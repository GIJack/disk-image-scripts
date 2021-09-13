PREFIX = usr/local/
install:
	install -Dm 755 mount_image.sh "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	install -Dm 755 shrinkwrap_image.sh "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	install -Dm 755 init_image.sh "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
	install -Dm 755 gen_cloud_template.sh "$(DESTDIR)/$(PREFIX)/bin/gen_cloud_template.sh"
	install -Dm 755 autorun/init.arch.sh "$(DESTDIR)/usr/share/disk-image-scripts/init.arch.sh"
	install -Dm 644 bash_completion/mount_image.bash "$(DESTDIR)/usr/share/bash-completion/completions/mount_image.sh"
	install -Dm 644 bash_completion/gen_cloud_template.bash "$(DESTDIR)/usr/share/bash-completion/completions/gen_cloud_template.sh"
	install -Dm 644 man/init_image.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/init_image.1"
	install -Dm 644 man/shrink_wrap.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/shrink_wrap.1"
	install -Dm 644 man/mount_image.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/mount_image.1"
	install -Dm 644 man/gen_cloud_template.1 "$(DESTDIR)/$(PREFIX)/share/man/man1/gen_cloud_template.1"
	install -Dm 644 man/template_rc.5 "$(DESTDIR)/$(PREFIX)/share/man/man5/template_rc.5"
	install -Dm 644 "docs/template.rc format spec.md" "$(DESTDIR)/usr/share/disk-image-scripts/docs/template.rc_format_spec.md"
	cp -ra default_template "$(DESTDIR)/usr/share/disk-image-scripts/default_template"
	
remove:
	rm "$(DESTDIR)/$(PREFIX)/bin/mount_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/bin/shrinkwrap_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/bin/init_image.sh"
	rm "$(DESTDIR)/$(PREFIX)/bin/gen_cloud_template.sh"
	rm "$(DESTDIR)/usr/share/disk-image-scripts/init.arch.sh"
	rm "$(DESTDIR)/usr/share/disk-image-scripts/init.arch.conf"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/init_image.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/shrink_wrap.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/mount_image.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man1/gen_cloud_template.1"
	rm "$(DESTDIR)/$(PREFIX)/share/man/man5/template_rc.5"
	rm "$(DESTDIR)/usr/share/bash-completion/completions/mount_image.sh"
	rm "$(DESTDIR)/usr/share/bash-completion/completions/gen_cloud_template.sh"
	rm -rf "$(DESTDIR)/usr/share/disk-image-scripts/"
