package:
	@mkdir -p release
	@for d in ./*.spoon; do \
		{ [ ! -d $$d ] || [ "$$d" = "./EmmyLua.spoon" ]; } && continue; \
		\
		echo "[Packaging] $$d"; \
		cd "$$d"; \
		zip -r "../release/$$(basename $$d).zip" "."; \
		cd ..; \
	done

.PHONY: package
