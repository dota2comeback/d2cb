Template.matchCreateModal.events
	'click .set-gametype-money': (e) ->
		$('.set-gametype-items').removeClass 'active'
		$('.set-gametype-money').addClass 'active'
		$('.match-type-items').hide()
		$('.match-type-money').fadeIn 500

	'click .set-gametype-items': (e) ->
		$('.set-gametype-money').removeClass 'active'
		$('.set-gametype-items').addClass 'active'
		$('.match-type-money').hide()
		$('.match-type-items').fadeIn 500
