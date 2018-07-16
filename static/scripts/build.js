({
    baseUrl: './lib/',
    mainConfigFile: 'app.js',
    paths: {
        requireLib: '../require',
        main: './main'
    },
    optimize: 'none',
    normalizeDirDefines: "all",
    name: "../app",
    out: "app-built.js",
    include: ["requireLib","main"]
})