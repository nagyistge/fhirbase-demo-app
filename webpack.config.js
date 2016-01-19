var etx = require("extract-text-webpack-plugin");
var webpack = require("webpack");

module.exports = {
  context: __dirname + "/src",
  entry: {
    app: "./coffee/app.coffee",
    tutor: "./coffee/tutor.coffee"
  },
  output: {
    path: __dirname + "/dist",
    filename: "[name].js"
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
  devServer: {
    headers: { "Access-Control-Allow-Origin": "http://127.0.0.1:8888" , "Access-Control-Allow-Credentials": "true"}
  },
  plugins: [
    new etx("app.css", {}),
    new webpack.DefinePlugin({
      BASEURL: JSON.stringify(process.env.BASEURL)
    })
  ],
  resolve: { extensions: ["", ".webpack.js", ".web.js", ".js", ".coffee", ".less", ".html"]}
};
