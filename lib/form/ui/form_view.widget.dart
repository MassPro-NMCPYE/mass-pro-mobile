// ignore_for_file: always_specify_types, always_declare_return_types

import 'package:d2_remote/core/common/value_type.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';

import '../../commons/custom_widgets/mixins/keyboard_manager.dart';
import '../../commons/extensions/dynamic_extensions.dart';
import '../../commons/extensions/standard_extensions.dart';
import '../../commons/helpers/collections.dart';
import '../../commons/helpers/iterable.dart';
import '../data/data_integrity_check_result.dart';
import '../model/Ui_render_type.dart';
import '../model/field_ui_model.dart';
import '../model/form_repository_records.dart';
import '../model/info_ui_model.dart';
import '../model/row_action.dart';
import '../model/section_ui_model_impl.dart';
import '../model/store_result.dart';
import '../model/value_store_result.dart';
import 'data_entry_items_list.widget.dart';
import 'di/form_view_notifier.dart';
import 'event/list_view_ui_events.dart';
import 'intent/form_intent.dart';
import 'provider/enrollment_result_dialog_ui_provider.dart';

class FormViewWidget extends ConsumerStatefulWidget {
  FormViewWidget(
      {super.key,
      this.needToForceUpdate = false,

      /// Sent ser. through
      required this.records,
      this.onItemChangeListener,
      this.onLoadingListener,
      this.onFocused,
      this.onFinishDataEntry,
      this.onActivityForResult,
      this.onPercentageUpdate,
      this.onDataIntegrityCheck,
      this.onFieldItemsRendered,
      this.onSavePicture,
      this.resultDialogUiProvider});

  // final LocationProvider? locationProvider;
  // TODO (NMC): make Injectable
  final bool needToForceUpdate;

  // TODO(NMC): make Injectable
  final EnrollmentResultDialogUiProvider? resultDialogUiProvider;

  /// Sent ser. through
  // Will be comming from event or Enrollment Widgets
  final FormRepositoryRecords records;

  final void Function(RowAction rowAction)? onItemChangeListener;
  final void Function(bool loading)? onLoadingListener;
  final void Function()? onFocused;
  final void Function()? onFinishDataEntry;
  final void Function()? onActivityForResult;
  final void Function(double percentage)? onPercentageUpdate;
  final void Function(DataIntegrityCheckResult result)? onDataIntegrityCheck;
  final void Function(bool fieldItemsRendered)? onFieldItemsRendered;

  //
  final void Function(String)? onSavePicture;

  //// in DataEntryAdapter
  final Map<String, int> sectionPositions = {};

  @override
  ConsumerState<FormViewWidget> createState() => _FormViewWidgetState();
}

class _FormViewWidgetState extends ConsumerState<FormViewWidget>
    with KeyboardManager {
  // late final FormViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: [
          DataEntryItemListWidget(
            onIntent: (intent) => _intentHandler(intent),
            onListViewUiEvents: (uiEvent) => _uiEventHandler(uiEvent),
          ),
          Positioned(
            right: 10,
            bottom: 0,
            child: FloatingActionButton(
              onPressed: () {
                onSaveClick();
              },
              tooltip: 'Save',
              elevation: 2.0,
              child: const Icon(Icons.save),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    _setUpRowActionStoreListener();
    _setObservers();
    // ref.read(itemsResultProvider.notifier).loadData();
    super.initState();
  }

  void _setUpRowActionStoreListener() {
    ref.listenManual<AsyncValue<Pair<RowAction, StoreResult>>>(
        rowActionStoreProvider,
        (AsyncValue<Pair<RowAction, StoreResult>>? previous,
            AsyncValue<Pair<RowAction, StoreResult>> next) {
      when(next.value?.second.valueStoreResult, {
        ValueStoreResult.VALUE_CHANGED: () {
          logInfo(info: 'itemsProvider: ValueStoreResult.VALUE_CHANGED');
          ref.read(formModelNotifierProvider.notifier).updateValue(
              (current) => current.copyWith(savedValue: next.value?.first));
          ref.read(formViewItemsProvider.notifier).processCalculatedItems();
        },
        ValueStoreResult.ERROR_UPDATING_VALUE: () {
          logInfo(info: 'itemsProvider: ValueStoreResult.ERROR_UPDATING_VALUE');
          ref.read(formModelNotifierProvider.notifier).updateValue((current) =>
              current.copyWith(showToast: 'string.update_field_error'));
        },
        ValueStoreResult.UID_IS_NOT_DE_OR_ATTR: () {
          logInfo(
              info:
                  'Timber.tag(TAG).d("${next.value?.first.id} is not a data element or attribute")');
          ref.read(formViewItemsProvider.notifier).processCalculatedItems();
        },
        ValueStoreResult.VALUE_NOT_UNIQUE: () {
          logInfo(info: 'itemsProvider: ValueStoreResult.VALUE_NOT_UNIQUE');
          ref.read(formModelNotifierProvider.notifier).updateValue((current) =>
              current.copyWith(
                  showInfo: const InfoUiModel(
                      'string.error', 'string.unique_warning')));
          ref.read(formViewItemsProvider.notifier).processCalculatedItems();
        },
        ValueStoreResult.VALUE_HAS_NOT_CHANGED: () =>
            ref.read(formViewItemsProvider.notifier).processCalculatedItems(),
        ValueStoreResult.TEXT_CHANGING: () {
          logInfo(info: 'itemsProvider: ValueStoreResult.TEXT_CHANGING');
          logInfo(
              info:
                  'Timber.d("${next.value?.first.id} is changing its value")');
          ref.read(formModelNotifierProvider.notifier).updateValue(
              (current) => current.copyWith(queryData: next.value?.first));
        },
        ValueStoreResult.FINISH: () {
          logInfo(info: 'itemsProvider: ValueStoreResult.FINISH');
          final itemsNotifier = ref.read(formViewItemsProvider.notifier);
          itemsNotifier
              .processCalculatedItems()
              .then((_) => itemsNotifier.runDataIntegrityCheck());
        }
      });
    });
  }

  void _setObservers() {
    // TODO(NMC): create loadingBar for this and initiate it when widget.onLoadingListener = null or call widget.onLoadingListener
    ref.listenManual<bool>(formViewLoadingProvider,
            (previous, next) => widget.onLoadingListener?.call(next));

    ref.listenManual<RowAction?>(
        formModelNotifierProvider.select((formModel) => formModel.savedValue),
            (previous, next) => next
            ?.let((rowAction) => widget.onItemChangeListener?.call(rowAction)));

    ref.listenManual<RowAction?>(
        formModelNotifierProvider.select((formModel) => formModel.queryData),
            (previous, next) => next?.let((rowAction) {
          if (widget.needToForceUpdate) {
            widget.onItemChangeListener?.let((it) => it(rowAction));
          }
        }));

    ref.listenManual<String?>(
        formModelNotifierProvider.select((formModel) => formModel.showToast),
            (previous, next) => next?.let((it) => showToast(it)));

    ref.listenManual<bool?>(formViewFocusedProvider,
            (previous, next) => next.let((it) => widget.onFocused?.call()));

    ref.listenManual<InfoUiModel?>(
        formModelNotifierProvider.select((formModel) => formModel.showInfo),
            (previous, next) =>
            next?.let((infoUiModel) => _showInfoDialog(infoUiModel)));

    ref.listenManual<DataIntegrityCheckResult?>(
        formModelNotifierProvider
            .select((formModel) => formModel.dataIntegrityResult),
            (previous, next) =>
            next?.let((result) => _handleDataIntegrityResult(result)));

    ref.listenManual<double>(
        completionPercentageProvider,
            (previous, next) => next
            .let((percentage) => widget.onPercentageUpdate?.call(percentage)));

    ref.listenManual<bool>(
        calculationLoopProvider,
            (previous, next) => next.let((displayLoopWarning) =>
        displayLoopWarning ? _showLoopWarning() : null));

    // ref.listenManual<FormIntent?>(uiIntentProvider,
    //     (previous, next) => next?.let((it) => _intentHandler(it)));
    //
    // ref.listenManual<ListViewUiEvents?>(uiEventProvider,
    //     (previous, next) => next?.let((it) => _uiEventHandler(it)));
  }

  void _uiEventHandler(ListViewUiEvents uiEvent) {
    uiEvent.map(
      openCustomCalendar: (OpenCustomCalendar uiEvent) =>
          _showCustomCalendar(uiEvent),
      openYearMonthDayAgeCalendar: (OpenYearMonthDayAgeCalendar uiEvent) =>
          _showYearMonthDayAgeCalendar(uiEvent),
      openTimePicker: (OpenTimePicker uiEvent) => _showTimePicker(uiEvent),
      showDescriptionLabelDialog: (ShowDescriptionLabelDialog uiEvent) =>
          _showDescriptionLabelDialog(uiEvent),
      requestCurrentLocation: (RequestCurrentLocation uiEvent) =>
          _requestCurrentLocation(uiEvent),
      requestLocationByMap: (RequestLocationByMap uiEvent) =>
          _requestLocationByMap(uiEvent),
      displayQRCode: (DisplayQRCode uiEvent) => _displayQRImage(uiEvent),
      scanQRCode: (ScanQRCode uiEvent) => _requestQRScan(uiEvent),
      openOrgUnitDialog: (OpenOrgUnitDialog uiEvent) =>
          _showOrgUnitDialog(uiEvent),
      addImage: (AddImage uiEvent) => _requestAddImage(uiEvent),
      showImage: (ShowImage uiEvent) => _showFullPicture(uiEvent),
      openOptionSetDialog: (OpenOptionSetDialog uiEvent) =>
          _showOptionSetDialog(uiEvent),
      copyToClipboard: (CopyToClipboard uiEvent) =>
          _copyToClipboard(uiEvent.value),
    );
  }

  _showCustomCalendar(OpenCustomCalendar uiEvent) {}

  _showYearMonthDayAgeCalendar(OpenYearMonthDayAgeCalendar uiEvent) {}

  _showTimePicker(OpenTimePicker uiEvent) {}

  _showDescriptionLabelDialog(ShowDescriptionLabelDialog uiEvent) {}

  _requestCurrentLocation(RequestCurrentLocation uiEvent) {}

  _requestLocationByMap(RequestLocationByMap uiEvent) {}

  _displayQRImage(DisplayQRCode uiEvent) {}

  _requestQRScan(ScanQRCode uiEvent) {}

  _showOrgUnitDialog(OpenOrgUnitDialog uiEvent) {}

  _requestAddImage(AddImage uiEvent) {}

  _showFullPicture(ShowImage uiEvent) {}

  _showOptionSetDialog(OpenOptionSetDialog uiEvent) {}

  _copyToClipboard(String? value) {}

  _showInfoDialog(InfoUiModel infoUiModel) {}

  _handleDataIntegrityResult(DataIntegrityCheckResult result) {
    if (widget.onDataIntegrityCheck != null) {
      widget.onDataIntegrityCheck?.call(result);
    } else {
      result.maybeMap(
          successfulResult: (_) => widget.onFinishDataEntry?.call(),
          orElse: () => _showDataEntryResultDialog(result));
    }
  }

  void _showDataEntryResultDialog(DataIntegrityCheckResult result) {
    // resultDialogUiProvider?.provideDataEntryUiModel(result)?.let {
    //     BottomSheetDialog(
    //         bottomSheetDialogUiModel = it,
    //         onSecondaryButtonClicked = {
    //             if (result.allowDiscard) {
    //                 viewModel.discardChanges()
    //             }
    //             onFinishDataEntry?.invoke()
    //         }
    //     ).show(childFragmentManager, AlertBottomDialog::class.java.simpleName)
    // }
  }

  _showLoopWarning() {}

  void _intentHandler(FormIntent intent) {
    ref
        .read(formPendingIntentsProvider.notifier)
        .submitIntent((current) => intent);
  }

  void _swap(List<FieldUiModel> updates, void Function() commitCallback) {
    widget.sectionPositions.clear();
    for (final FieldUiModel fieldViewModel in updates) {
      if (fieldViewModel is SectionUiModelImpl) {
        widget.sectionPositions[fieldViewModel.uid] =
            updates.indexOf(fieldViewModel);
      }
    }

    // submitList(updates) {
    commitCallback.call();
    // }
  }

  void onEditionFinish() {
    // TODO(NMC): implement onEditionFinish
    // binding.recyclerView.requestFocus();
  }

  int _negativeOrZero(String value) {
    if (value.isEmpty) {
      return 0;
    } else {
      return -(int.tryParse(value) ?? 0);
    }
  }

  void clearValues() {
    _intentHandler(const FormIntent.onClear());
  }

  void onBackPressed() {
    ref
        .read(formViewItemsProvider.notifier)
        .runDataIntegrityCheck(backButtonPressed: true);
  }

  void onSaveClick() {
    onEditionFinish();
    ref.read(formViewItemsProvider.notifier).saveDataEntry();
    // viewModel.saveDataEntry();
  }

  void reload() {
    // viewModel.loadData();
  }

  void _render(IList<FieldUiModel> items) {
    // viewModel.calculateCompletedFields();
    // TODO(NMC): implementing Rules
    // viewModel.updateConfigurationErrors();
    // viewModel.displayLoopWarningIfNeeded();
    // viewModel.displayLoopWarningIfNeeded();

    _handleKeyBoardOnFocusChange(items);
  }

  void _handleKeyBoardOnFocusChange(IList<FieldUiModel> items) {
    items.firstOrNullWhere((FieldUiModel it) => it.focused)?.let(
            (FieldUiModel fieldUiModel) =>
            fieldUiModel.valueType?.let((ValueType valueType) {
              if (!valueTypeIsTextField(valueType)) {
                hideTheKeyboard(context);
              }
            }));
  }

  bool valueTypeIsTextField(ValueType valueType, [UiRenderType? renderType]) {
    return valueType.isNumeric ||
        valueType.isText && renderType?.isPolygon != true ||
        valueType == ValueType.URL ||
        valueType == ValueType.EMAIL ||
        valueType == ValueType.PHONE_NUMBER;
  }
}
