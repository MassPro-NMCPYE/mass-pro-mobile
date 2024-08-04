import 'dart:async';

import 'package:d2_remote/d2_remote.dart';
import 'package:d2_remote/modules/datarun/form/entities/form_definition.entity.dart';
import 'package:d2_remote/modules/datarun/form/shared/dynamic_form_field.entity.dart';
import 'package:d2_remote/modules/datarun/form/shared/form_option.entity.dart';
import 'package:d2_remote/modules/datarun/form/shared/rule.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:mass_pro/data_run/errors_management/errors/form_does_not_exist.exception.dart';
import 'package:mass_pro/data_run/utils/get_item_local_string.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'form_configuration.g.dart';

@riverpod
Future<FormConfiguration> formConfiguration(
    FormConfigurationRef ref, String form,
    [int? version]) async {
  final currentForm = await D2Remote.formModule.form
      .byId(form)
      .getOne();

  if (currentForm == null) {
    throw FormDoesNotExistException('formUid: $form dose not exist');
  }

  final FormDefinition? formDefinition = await D2Remote
      .formModule.formDefinition
      .byForm(form)
      .byVersion(version ?? currentForm.version)
      .getOne();
  return FormConfiguration(
      form: form,
      label: getItemLocalString(formDefinition?.label,
          defaultString: currentForm.name),
      version: formDefinition?.version ?? currentForm.version,
      fields: formDefinition?.fields,
      options: formDefinition?.options);
}

class FormConfiguration {
  FormConfiguration(
      {List<DynamicFormField>? fields,
      List<FormOption>? options,
      required this.form,
      required this.label,
      required this.version})
      : this.fields =
            IMap.fromIterable<String, DynamicFormField, DynamicFormField>(
                fields ?? [],
                keyMapper: (DynamicFormField field) => field.name,
                valueMapper: (DynamicFormField field) => field),
        this.optionLists =
            IMap.fromIterable<String, IList<FormOption>, FormOption>(
                options ?? [],
                keyMapper: (FormOption option) => option.name,
                valueMapper: (FormOption option) =>
                    options
                        ?.where((o) => o.listName == option.listName)
                        .toIList() ??
                        const IListConst([])),
        this.fieldRules =
            IMap.fromIterable<String, IList<Rule>?, DynamicFormField>(
                fields ?? [],
                keyMapper: (DynamicFormField field) => field.name,
                valueMapper: (DynamicFormField field) => field.rules?.lock);

  final String form;

  final String label;

  final int version;

  /// {field.name: field}
  final IMap<String, DynamicFormField> fields;

  /// {listName: option}
  final IMap<String, IList<FormOption>> optionLists;

  /// {field.name: rule}
  final IMap<String, IList<Rule>?> fieldRules;
}