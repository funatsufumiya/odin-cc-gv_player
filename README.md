# GV video player for [odin-cc](https://github.com/cc4v/odin-cc)

Using [odin-gv](https://github.com/funatsufumiya/odin-gv). Forked from [v_gvvideo](https://github.com/funatsufumiya/v_gvvideo) (player part).

![docs/screenshot.png](./docs/screenshot.png)

## Examples

```bash
$ odin run examples/single
$ odin run examples/multiple

# NOTE: you can pass your gv files
#
# $ odin run examples/single -- your_file.gv
# $ odin run examples/multiple -- file1.gv file2.gv file3.gv ...
# $ odin run examples/multiple -- your_dir_containing_gv_files
```

## Note

This repository has recursive git submoduels. So you need `git clone --recursive`.