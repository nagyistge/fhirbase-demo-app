var etx = require("extract-text-webpack-plugin");
var webpack = require("webpack");

module.exports = {
  context: __dirname + "/src",
  entry: "./coffee/app.coffee",
  output: {
    path: __dirname + "/dist",
    filename: "app.js"
  },
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee-loader" },
      { test: /\.png$/, loader: "file-loader" },
      { test: /\.gif$/, loader: "file-loader" },
      { test: /\.(ttf|eot|woff|woff2|svg|swf)$/, loader: "file-loader" },
      { test: /\.eot$/, loader: "file-loader" },
      { test: /\.less$/,   loader: etx.extract("style-loader","css-loader!less-loader")},
      { test: /\.css$/,    loader: etx.extract("style-loader", "css-loader") },
      { test: /templates\/.*?\.html$/,   loader: "ng-cache?prefix=templates/fs/" },
      { test: /\.md$/, loader: "html!markdown" },
      { test: /views\/.*?\.html$/,   loader: "ng-cache?prefix=/views/" }
    ]
  },
  plugins: [
    new etx("app.css", {}),
    new webpack.DefinePlugin({
      BASEURL: JSON.stringify(process.env.BASEURL),
      OAUTH_RESPONSE_TYPE: JSON.stringify(process.env.OAUTH_RESPONSE_TYPE),
      OAUTH_AUTHORIZE_URI: JSON.stringify(process.env.OAUTH_AUTHORIZE_URI),
      OAUTH_ACCESS_TOKEN_URI: JSON.stringify(process.env.OAUTH_ACCESS_TOKEN_URI),
      OAUTH_REDIRECT_URI: JSON.stringify(process.env.OAUTH_REDIRECT_URI),
      OAUTH_CLIENT_ID: JSON.stringify(process.env.OAUTH_CLIENT_ID),
      OAUTH_CLIENT_SECRET: JSON.stringify(process.env.OAUTH_CLIENT_SECRET),
      OAUTH_SCOPE: JSON.stringify(process.env.OAUTH_SCOPE)
    })
  ],
  resolve: { extensions: ["", ".webpack.js", ".web.js", ".js", ".coffee", ".less"]}
};
