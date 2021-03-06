config = require './config'
PlugAPI = require 'plugapi'
EventEmitter = require('events').EventEmitter
Prompt = require './prompt'
UserCache = require './usercache'
ModuleManager = require './modulemanager'
vm = require 'vm'
domain = require 'domain'

class RoboJar
	constructor: (key)->
		#module stuff
		@eventProxies = {}
		@domains = {}

		@prompt = new Prompt()
		@prompt.setStatusLines [@prompt.clc.blackBright("Not connected")]

		@module = new ModuleManager @prompt, @

		@bot = new PlugAPI key
		@bot._emit = @bot.emit
		@bot.emit = =>
			@module.proxyEvent arguments
			@bot._emit.apply(@bot, arguments)

		@bot.on 'error', @connect
		@bot.on 'close', @connect

		@bot.on 'error', (data)=>
			@prompt.setStatusLines [@prompt.clc.red("Error!")]
		@bot.on 'close', =>
			@prompt.setStatusLines [@prompt.clc.blackBright("Not connected")]
		@bot.setLogObject(@prompt)

		@prompt.on 'line', (msg)=>
			if (msg.charAt(0) == "/")
				if (msg.charAt(1) == " ")
					msg = "/"+msg.substring(2)
				else
					return @parseCommand msg

			@bot.chat msg

		@connect()

		@bot.on 'chat', @chat
		@bot.on 'connected', =>
			@prompt.setStatusLines [@prompt.clc.yellow("Joining room...")]
		@bot.on 'djAdvance', (data)=>
			@currentSong = data.media
			@setStatusLines()
		@bot.on 'roomChanged', (data)=>
			@userCache = new UserCache(data.room.users, @prompt, @module.getEventProxy("usercache"))
			@userCache.on 'changed', @setStatusLines
			@room = data.room
			@currentSong = data.room.media
			@setStatusLines()

	setStatusLines: =>
		@prompt.setStatusLines [
			@prompt.clc.green("Connected!") + " " + @prompt.clc.bold("#{ @room.name }") + ", " + @prompt.clc.yellowBright(@userCache.count()) + " users.",
			"Current song: #{ @currentSong.title } by #{ @currentSong.author }"
			]

	parseCommand: (msg)->
		index = msg.indexOf(" ")
		if index < 1 then index = msg.length
		cmd = msg.substring(1, index)

		if index == msg.length
			args = null
		else
			args = msg.substring index

		switch cmd
			when "e"
				try
					result = vm.runInContext args, context
					@prompt.log result
				catch e
					@prompt.log e
			when "l"
				args = args.trim()
				if (args == "usercache")
					@prompt.setStatusLines [@prompt.clc.yellow("Joining room...")]
					delete require.cache[require.resolve("./usercache")]
					delete @eventProxies["usercache"]
					delete @domains["usercache"]
					UserCache = require './usercache'
					@bot.joinRoom "coding-soundtrack"
				else
					@module.loadModule args

	chat: (data)=>
		if (data.type == "emote")
			@prompt.log @prompt.clc.blackBright(data.from + data.message)
		else
			@prompt.log @prompt.clc.blue(data.from+": ") + data.message

	connect: =>
		@bot.connect 'coding-soundtrack'

bot = roboJar = new RoboJar(config.auth)

scope = 
	bot: bot
	roboJar: roboJar
	prompt: bot.prompt
	require: require

context = vm.createContext scope
