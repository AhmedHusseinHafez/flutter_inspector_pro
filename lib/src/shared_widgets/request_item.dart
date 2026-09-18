import 'package:flutter/material.dart';

import '../../requests_inspector.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';
import 'status_method_chip.dart';

class RequestItemWidget extends StatelessWidget {
  const RequestItemWidget({
    super.key,
    required RequestDetails request,
    required bool isSelected,
    required bool isDarkMode,
    required void Function(BuildContext context, RequestDetails request) onTap,
  })  : _request = request,
        _isSelected = isSelected,
        _isDarkMode = isDarkMode,
        _onTap = onTap;

  final RequestDetails _request;
  final bool _isSelected;
  final bool _isDarkMode;
  final void Function(BuildContext context, RequestDetails request) _onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isSelected
        ? InspectorTheme.primary
        : InspectorTheme.border(_isDarkMode);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(InspectorTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onTap(context, _request),
        child: Container(
          decoration: BoxDecoration(
            color: InspectorTheme.surface(_isDarkMode),
            borderRadius: BorderRadius.circular(InspectorTheme.radius),
            border: Border.all(
              color: borderColor,
              width: _isSelected ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MethodChip(method: _request.requestMethod),
                        const SizedBox(width: 6.0),
                        StatusChip(statusCode: _request.statusCode),
                      ],
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      _request.requestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      _request.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: _isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                _request.receivedTime != null
                    ? InspectorHelper.calculateDuration(
                        _request.sentTime,
                        _request.receivedTime!,
                      )
                    : InspectorHelper.extractTimeText(_request.sentTime),
                style: TextStyle(
                  fontSize: 11.0,
                  color: _isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
