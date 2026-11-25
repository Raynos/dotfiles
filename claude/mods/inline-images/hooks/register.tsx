import type { Register, EngineInterface } from 'claude-code'

// Claude Code draws a sent image as a text row: `› [image] ~/path.jpg (size)`.
// This mod keeps that row and draws the picture under it with the terminal
// `Image` element (kitty graphics: Herdr, Ghostty, kitty).
//
// `Image` reads PNG files only, so each image is turned into a PNG thumbnail
// with macOS `sips` once and cached under CACHE, keyed by path + size.

// v2: thumbnails capped at 800px so the base64 stays well under 2 MiB.
const CACHE = '/private/tmp/claude-inline-images/v2'
const MAX_COLUMNS = 64
const MAX_ROWS = 24
// Terminal cells are about twice as tall as wide (9x18 px in Herdr).
const CELL_ASPECT = 0.5

type Attachment = { path: string; size: number; isImage: boolean }
type Picture = { png: string; width: number; height: number }

// Module variable on purpose: a cache only, rebuilt after a reload.
const pictures = new Map<string, Promise<Picture | null>>()

const hash = (s: string) => {
  let h = 5381
  for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0
  return h.toString(16)
}

const toPicture = async ($: EngineInterface, a: Attachment): Promise<Picture | null> => {
  const png = `${CACHE}/${hash(`${a.path}:${a.size}`)}.png`
  if (!(await $.fs.exists(png))) {
    await $.process.run(['mkdir', '-p', CACHE])
    const made = await $.process.run(['sips', '-s', 'format', 'png', '-Z', '800', a.path, '--out', png])
    if (made.exitCode !== 0) return null
  }
  const dims = await $.process.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', png])
  const width = Number(/pixelWidth:\s*(\d+)/.exec(dims.stdout)?.[1])
  const height = Number(/pixelHeight:\s*(\d+)/.exec(dims.stdout)?.[1])
  if (!(width > 0 && height > 0)) return null
  // Bytes, not `{ file }`: Herdr's terminal does not read files itself
  // (kitty `t=f`), so a file source draws only the alt text there.
  const { base64 } = await $.fs.read(png, { as: 'bytes' })
  return { png: base64, width, height }
}

const pictureOf = ($: EngineInterface, a: Attachment) => {
  const key = `${a.path}:${a.size}`
  let p = pictures.get(key)
  if (p === undefined) {
    p = toPicture($, a).catch(() => null)
    pictures.set(key, p)
  }
  return p
}

const fit = (pic: Picture, available: number) => {
  let columns = Math.max(8, Math.min(MAX_COLUMNS, available))
  let rows = Math.round((columns * pic.height * CELL_ASPECT) / pic.width)
  if (rows > MAX_ROWS) {
    rows = MAX_ROWS
    columns = Math.max(1, Math.round((rows * pic.width) / (pic.height * CELL_ASPECT)))
  }
  return { columns: Math.min(255, columns), rows: Math.max(1, Math.min(255, rows)) }
}

export const register: Register = on => {
  for (const tool of ['SendUserFile', 'SendUserMessage']) {
    on('ui.render', { component: 'ToolUse', props: { tool } }, async ($, e, next) => {
      const row = await next(e)
      if (e.surface !== 'terminal') return row

      const output = e.props.output as { attachments?: Attachment[] } | undefined
      const images = (output?.attachments ?? []).filter(
        a => a.isImage && a.path.startsWith('/'),
      )
      if (images.length === 0) return row

      const pics = await Promise.all(images.map(a => pictureOf($, a)))
      const { Box, Image } = $.ui.resolve(e)
      const available = (e.viewport?.columns ?? 80) - 6

      return (
        <Box flexDirection="column">
          {row}
          {pics.map((pic, i) => {
            if (pic === null) return null
            const { columns, rows } = fit(pic, available)
            return (
              <Box key={`img-${i}`} paddingLeft={4} marginTop={1}>
                <Image
                  source={{ png: pic.png }}
                  columns={columns}
                  rows={rows}
                  alt={images[i]?.path.split('/').pop() ?? 'image'}
                />
              </Box>
            )
          })}
        </Box>
      )
    })
  }
}
