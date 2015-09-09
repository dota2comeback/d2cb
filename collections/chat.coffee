Meteor.methods
	chatSendMessage: (message) ->
		@unblock()

		if @userId and message
			check message, String

			Chat.insert
				message: message
				userId: @userId
				date: Date.now()

Chat.helpers
	user: ->
		Meteor.users.findOne
			_id: @userId
		,
			fields:
				id: 1
				'profile.name': 1
				'services': 1