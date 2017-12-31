run: restart
	$(SILENT) tail -f ./jekyll.log
.PHONY: run

start:
	$(SILENT) ./jekyll start
.PHONY: start

stop:
	$(SILENT) ./jekyll stop
.PHONY: stop

restart:
	$(SILENT) ./jekyll restart
.PHONY: restart

