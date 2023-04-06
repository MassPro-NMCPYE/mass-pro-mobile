import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../commons/resources/resource_manager.dart';

class EventCaptureResourcesProvider {
  EventCaptureResourcesProvider(this.resourceManager);

  final ResourceManager resourceManager;

  IconData provideRedAlertIcon() =>
      Icons.error_outline; //R.drawable.ic_error_outline;

  IconData provideYellowAlertIcon() => MdiIcons.alert; //R.drawable.ic_alert;

  IconData provideSavedIcon() =>
      Icons.save_rounded; //R.drawable.ic_saved_check;

  String provideNotSavedText() => resourceManager.getString('not_saved');

  String provideSavedText() => resourceManager.getString('saved');

  String provideErrorInfo() =>
      resourceManager.getString('missing_error_fields_events');

  String provideMandatoryInfo() =>
      resourceManager.getString('missing_mandatory_fields_events');

  String provideMandatoryField() =>
      resourceManager.getString('field_is_mandatory');

  String provideWarningInfo() =>
      resourceManager.getString('missing_warning_fields_events');

  String provideReview() =>
      resourceManager.getString('review'); //'R.string.review

  String provideNotNow() =>
      resourceManager.getString('not_now'); //'R.string.not_now

  String provideCompleteInfo() =>
      resourceManager.getString('event_can_be_completed');

  String provideOnCompleteErrorInfo() =>
      resourceManager.getString('event_error_on_complete');
}
