hasMoreMatchesFinished = -> Config.get('matchesTotalCount') - Matches.find(status: 'finished').count() > 0

Template.index.helpers
	hasMoreMatchesFinished: hasMoreMatchesFinished

Template.gamesFinished.rendered = ->
	Deps.autorun ->
		Meteor.subscribe 'matchesFinishedList', Session.get 'matchesFinishedLimit'

	Session.setDefault 'matchesFinishedLimit', 20
	#$('[data-toggle=tooltip]').tooltip()

Template.gamesFinished.events
	'click .btn-more-matches': ->
		if hasMoreMatchesFinished()
			matchesLimit = Session.get 'matchesFinishedLimit'
			Session.set 'matchesFinishedLimit', matchesLimit + 25