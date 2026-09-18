import 'package:flutter/material.dart';

import '../../requests_inspector.dart';
import '../helpers/inspector_helper.dart';
import 'inspector_theme.dart';

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
    final methodColor = InspectorTheme.colorForMethod(_request.requestMethod);
    final statusColor = InspectorTheme.colorForStatusCode(_request.statusCode);

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
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.0,
                height: 36.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: methodColor,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  _methodAbbreviation(_request.requestMethod),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _request.statusCode?.toString() ?? 'Err',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 2.0),
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
            ],
          ),
        ),
      ),
    );
  }

  String _methodAbbreviation(RequestMethod method) {
    // Keep it to 5 chars max so it fits the fixed-width badge.
    final name = method.name;
    return name.length <= 5 ? name : name.substring(0, 5);
  }
}
