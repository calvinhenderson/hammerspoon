package:
	@mkdir -p release
	@for d in ./*.spoon; do \
		{ [ ! -d $$d ] || [ "$$d" = "./EmmyLua.spoon" ]; } && continue; \
		\
		echo "[Packaging] $$d"; \
		zip -r "./release/$$(basename $$d).zip" "$$d"; \
	done

.PHONY: package
