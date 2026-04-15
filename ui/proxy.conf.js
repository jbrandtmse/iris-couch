module.exports = {
  [`^/iris-couch/_utils/(?!(login|databases|db(/|$)|active-tasks|setup|about|favicon\\.ico|@|.*\\.(js|mjs|css|map|ico|woff2?|ttf|svg|png|jpe?g|gif|html)(\\?.*)?$)).+`]: {
    target: 'http://localhost:52773',
    secure: false,
    changeOrigin: true,
    pathRewrite: { '^/iris-couch/_utils': '/iris-couch' },
  },
};
