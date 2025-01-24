package desktop

import game ".."
import rl "vendor:raylib"

main :: proc() {
	game.init()
	defer game.shutdown()

	for game.should_run() {
		game.update()
	}
}
