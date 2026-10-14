'use strict'

// Canvas CSS still uses deprecated Sass features. Those warnings are harmless
// and large enough to hit the BuildKit log cap before the real error appears.
const Module = require('module')
const orig = Module.prototype.require
const silence = ['legacy-js-api', 'import', 'global-builtin', 'color-functions']

function patch(exported) {
  if (!exported || exported.__opeSilence) return exported
  for (const name of ['compile', 'compileAsync', 'compileString', 'compileStringAsync', 'render', 'renderSync']) {
    if (typeof exported[name] !== 'function') continue
    const fn = exported[name]
    const optionsFirst = name === 'render' || name === 'renderSync'
    exported[name] = function () {
      const args = Array.prototype.slice.call(arguments)
      const opts = args[optionsFirst ? 0 : 1]
      if (opts && typeof opts === 'object') {
        opts.silenceDeprecations = silence
        opts.verbose = false
      }
      return fn.apply(this, args)
    }
  }
  try {
    exported.__opeSilence = true
  } catch (e) {}
  return exported
}

Module.prototype.require = function (id) {
  const exported = orig.apply(this, arguments)
  return id === 'sass' ? patch(exported) : exported
}
