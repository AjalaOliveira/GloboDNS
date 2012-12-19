$(document).ready(function() {
	// ------------------- BIND -------------------
	$('.reload-bind-config-button').live('click', function () {
		$.rails.handleRemote($(this));
		return false;
	}).live('ajax:success', function (evt, data, statusStr, xhr) {
		$('textarea#named_conf').val(data);
		return false;
	}).live('ajax:error', function (evt, xhr, statusStr, error) {
		alert("[ERROR] reload failed");
	});

	$('.bind-export-button').live('click', function () {
		$(this).data('params', $(this).data('params') + '&' + $('textarea#master-named-conf').serialize() + '&' + $('textarea#slave-named-conf').serialize());
		$.rails.handleRemote($(this));
		return false;
	}).live('ajax:beforeSend', function (xhr, settings) {
		$('.export-output').hide();
		$('.export-output').html();
	}).live('ajax:success', function (evt, data, statusStr, xhr) {
		$('.export-output').html(data)
		$('.export-output').show();
	}).live('ajax:error', function (evt, xhr, statusStr, error) {
		if (xhr.status == 422) { // :unprocessable_entity
			$('.export-output').html(xhr.responseText)
			$('.export-output').show();
		} else
			alert("[ERROR] export failed");
	});

	// -- Export menu item; show only to "operator" users
	$('.export-menu-item').live('ajax:success', function(evt, data, statusStr, xhr) {
		$.fn.flashMessage(data.output, 'notice', 5000);
	}).live('ajax:error', function (evt, xhr, statusStr, error) {
		alert("[ERROR] export failed");
	});
});
