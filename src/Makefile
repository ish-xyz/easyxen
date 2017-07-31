.PHONY: all

target_file = ../library/easyxen

create:
        @touch $(target_file)

basic:
        @cat ./lib/basic.sh > "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"

cmds:
        @cat ./cmd/present.sh >> "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"
        @cat ./cmd/absent.sh >> "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"
        @cat ./cmd/halt.sh >> "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"
        @cat ./cmd/run.sh >> "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"
        @cat ./cmd/reconfigure.sh >> "$(target_file)"
        @echo -ne "\n\n" >> "$(target_file)"
        @cat ./cmd/main.sh >> "$(target_file)"

build: create basic cmds
