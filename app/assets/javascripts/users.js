/*
* Licensed to the Apache Software Foundation (ASF) under one or more
* contributor license agreements.  See the NOTICE file distributed with
* this work for additional information regarding copyright ownership.
* The ASF licenses this file to You under the Apache License, Version 2.0
* (the "License"); you may not use this file except in compliance with
* the License.  You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
$(document).ready(function() {
    $('.new-user-button').click(function () {
        $(this).hide();
        $('.new-user-form-container').show();
        return false;
    });

    $('#users-table-pagination a').live('ajax:success', function (evt, data, statusStr, xhr) {
        $('.users-table-container').replaceWith(data);
    }).live('ajax:error', function () {
        alert("[ERROR] unable to retrieve users");
    });

    $('.cancel-new-user-button').live('click', function () {
        $('.new-user-form-container').hide();
        $('.new-user-button').show();
        return false;
    });

    $('.new-user-form input').live('keypress', function (evt) {
        if (evt.which === 13) {
            $('.create-user-button').click();
            return false;
        }
    });

    $('.new-user-form').live('ajax:success', function (evt, data, statusStr, xhr) {
        $('table#users-table tbody').append(data);
        $('.new-user-form-container ul.errors').remove();
        fixUsersTableZebraStriping();
	}).live('ajax:error', function (evt, xhr, statusStr, error) {
		if (xhr.status == 422) { // :unprocessable_entity
			$('.new-user-form-container ul.errors').remove();
			$('.new-user-form-container').prepend(xhr.responseText);
		} else
			alert("[ERROR] unable to create Domain");
    });

    $('.edit-user-button').live('click', function () {
        var height = $(this).closest('tr').height();
        $(this).closest('tr').hide();
        $(this).closest('tr').next().height(height);
        $(this).closest('tr').next().show();
        return false;
    });

    $('.update-user-button').live('click', function () {
        // copy inputs from phony form to real form
        var form = $(this).closest('tr').prev().prev().find('form.update-user-form');
        $(this).closest('tr').find('input').each(function (idx, input) {
            form.append($(input).clone());
        });
        $(this).closest('tr').find('select').each(function (idx, input) {
            var clonedSelect = $(input).clone();
            clonedSelect.val($(input).val());
            form.append(clonedSelect);
        });

        form.submit();
        return false;
    });

    $('tr.edit-user input').live('keypress', function (evt) {
        if (evt.which === 13)
            $(this).closest('tr').find('.update-user-button').click();
    });

    $('.cancel-edit-user-button').live('click', function () {
        $(this).closest('tr').hide();
        $(this).closest('tr').prev().show();
        return false;
    });

    $('.update-user-form').live('ajax:success', function (evt, data, statusStr, xhr) {
        $('.users-table-container ul').remove();
        var markerRow = $(this).closest('tr');
        markerRow.before(data);
        markerRow.next().next().remove();
        markerRow.next().remove();
        markerRow.remove();
        fixUsersTableZebraStriping();
    }).live('ajax:error', function (evt, xhr, statusStr, error) {
        if (xhr.status == 422) { // :unprocessable_entity
            $('.users-table-container ul').remove();
            $('.users-table-container').prepend(xhr.responseText);
        } else
            alert("[ERROR] unable to update User");
    });

    $('.delete-user-button').live('ajax:success', function () {
        var row  = $(this).closest('tr');
        var prev = row.prev();
        var next = row.next();
        next.remove(); row.remove(); prev.remove();
        fixUsersTableZebraStriping();
    }).live('ajax:error', function () {
        alert("[ERROR] unable to delete User");
    });


    var fixUsersTableZebraStriping = function () {
        $('table#users-table tr.show-user:nth-child(even), table#users-table tr.edit-user:nth-child(odd)').addClass("even").removeClass("odd");
        $('table#users-table tr.show-user:nth-child(odd), table#users-table tr.edit-user:nth-child(even)').addClass("odd").removeClass("even");
    }

});
