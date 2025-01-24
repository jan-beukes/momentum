SRC = momentum.odin

all: desktop

desktop: desktop/main.odin $(SRC)
	odin build desktop -out:momentum
web: web/main.odin $(SRC)
	./build_web.sh
