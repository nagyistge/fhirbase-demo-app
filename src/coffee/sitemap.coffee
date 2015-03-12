app = require('./module')

capitalize = (s)->
  s && s[0].toUpperCase() + s.slice(1)

buildSiteMap = (x)->
  x.href ||= "#/#{x.name}"
  x.templateUrl ||= "/views/#{x.name}.html"
  x.controller ||= "#{capitalize(x.name)}Controller"
  x

module.exports = {
  main: [
    {
        label: "Hospital",
        name: "new",
        href: "#/new",
        path: "/new/",
        scope: "doctor",
        allowed: false
    }, {
        label: "Laboratory",
        name: "index",
        href: "#/index",
        path: "/index",
        scope: "laboratory",
        allowed: false}
  ].map(buildSiteMap)
}
