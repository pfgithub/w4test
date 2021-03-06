## Pl¢tfarmer

A clicker/platformer game built for the [wasm4j](https://itch.io/jam/wasm4)am

[![Play Game](src/platformer-thumbnail-playbtn.png)](https://pfg.itch.io/plctfarmer)

https://pfg.itch.io/plctfarmer

Source code is in `src/platformer.zig`

Map is in `src/platformer.png`

Texture compressor is in `src/imgconv.zig`

How to build (dev):

```
zig build
w4 run -n zig-out/lib/platformer.wasm
```

<details>
<summary>Notes</summary>

make sure you aren't over the size limit:
`zig build -Drelease-small && ls -l zig-out/lib/platformer.wasm`
(maximum is 65,536 bytes)

recommend also using wasm-opt -Oz because it got likt 50kb → 46kb

check this: `wasm-objdump zig-out/lib/platformer.wasm -x -j code`

## ingconv notes

1. scale the image down to 160x160
2. https://www.imgonline.com.ua/eng/limit-color-number.php
3. imgconv image.jpg image.w4i --compress --detect-palette

## bundling

```
zig build -Drelease-small && ls -l zig-out/lib/platformer.wasm && w4 bundle zig-out/lib/platformer.wasm --html zig-out/lib/file.html
```

note: also use wasm-opt

## TODO:

- [x] finish up the game
  - [x] intro screen. the computer thing and a clicker game → the full game
  - [x] pause menu so you can go back out to the computer. it would be cool to
        have interactions between the game and the computer but idk
  - [x] end screen. you unlock infinite dashes + debug keys
- [ ] see how many desktop backgrounds I can fit in the cart
  - [ ] `wasm-opt -Oz --strip-producers --dce --zero-filled-memory` ← make sure
        to use this, it will make the zig output even smaller
  - [ ] see if we can go right the way up to the limit
  - [ ] oh yeah we could do that before release, why not

</details>