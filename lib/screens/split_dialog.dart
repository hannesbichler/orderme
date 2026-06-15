import 'package:flutter/material.dart';

import '../models/orderitem.dart';
import '../models/orderline.dart';
import 'checkout_dialog.dart';

class SplitDialog {
	static Future<double?> show({
		required BuildContext context,
		required OrderItem orderitem,
		required String placeName,
	}) async {
		if (orderitem.lines.isEmpty) return null;

		final splitQuantities = List<int>.filled(orderitem.lines.length, 0);
		int? selectedRowIndex;
		bool? selectedIsSplitList;

		return showDialog<double>(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (ctx, setDialogState) {
					final lines = orderitem.lines;
					final splitLines = <OrderLine>[];

					for (var i = 0; i < lines.length; i++) {
						final line = lines[i];
						final splitQty = splitQuantities[i];
						if (splitQty > 0) {
							splitLines.add(OrderLine(
								id: line.id,
								orderId: line.orderId,
								productId: line.productId,
								productName: line.productName,
								pricesell: line.pricesell,
								qty: splitQty,
                attSetInstDesc: line.attSetInstDesc,
								qtyNew: 0,
                attributes: line.attributes,
							));
						}
					}

					final splitTotal =
							splitLines.fold<double>(0, (sum, line) => sum + line.total);
					final remainingTotal = orderitem.total - splitTotal;

					void changeSplitQty(int index, int delta) {
						final nextValue = (splitQuantities[index] + delta)
								.clamp(0, lines[index].qty)
								.toInt();
						setDialogState(() {
							splitQuantities[index] = nextValue;

							if (selectedRowIndex == index) {
								final hasCurrent = lines[index].qty - splitQuantities[index] > 0;
								final hasSplit = splitQuantities[index] > 0;

								if (selectedIsSplitList == true && !hasSplit) {
									if (hasCurrent) {
										selectedIsSplitList = false;
									} else {
										selectedRowIndex = null;
										selectedIsSplitList = null;
									}
								} else if (selectedIsSplitList == false && !hasCurrent) {
									if (hasSplit) {
										selectedIsSplitList = true;
									} else {
										selectedRowIndex = null;
										selectedIsSplitList = null;
									}
								}
							}
						});
					}

					bool isRowSelected(int index, bool isSplitList) {
						if (selectedRowIndex != index) return false;
						if (selectedIsSplitList != isSplitList) return false;
						return true;
					}

					void moveSelectedOne() {
						if (selectedRowIndex == null || selectedIsSplitList == null) {
							return;
						}
						setDialogState(() {
							if (selectedIsSplitList!) {
								changeSplitQty(selectedRowIndex!, -1);
							} else {
								changeSplitQty(selectedRowIndex!, 1);
							}
						});
					}

					void moveSelectedAll() {
						if (selectedRowIndex == null || selectedIsSplitList == null) {
							return;
						}
						setDialogState(() {
							splitQuantities[selectedRowIndex!] =
									selectedIsSplitList! ? 0 : lines[selectedRowIndex!].qty;
						});
					}

					Widget buildLineTile({
						required int index,
						required OrderLine line,
						required int qty,
						required bool selected,
						required VoidCallback onSelect,
					}) {
						return InkWell(
							onTap: onSelect,
							child: Container(
								color: selected
									? const Color(0xFFE3EAFF)
									: Colors.transparent,
								padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
								child: Row(
									children: [
										Expanded(
											child: Text(
												line.productName,
												overflow: TextOverflow.ellipsis,
												style: TextStyle(
													fontSize: 13,
													fontWeight: selected
														? FontWeight.bold
														: FontWeight.normal,
													color: selected ? const Color(0xFF1A237E) : null,
												),
											),
										),
										const SizedBox(width: 8),
										Text(
											'x$qty',
											style: TextStyle(
												fontSize: 13,
												fontWeight: selected
													? FontWeight.bold
													: FontWeight.normal,
											),
										),
										const SizedBox(width: 8),
										Text(
											'€${(line.pricesell * qty).toStringAsFixed(2)}',
											style: TextStyle(
												fontSize: 12,
												color: selected
													? const Color(0xFF1A237E)
													: const Color(0xFF3A6FFF),
												fontWeight: FontWeight.w600,
											),
										),
									],
								),
							),
						);
					}

					Widget buildListSection({
						required String title,
						required bool active,
						required Widget child,
					}) {
						return AnimatedContainer(
							duration: const Duration(milliseconds: 160),
							padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
							decoration: BoxDecoration(
								color: active ? const Color(0xFFF4F7FF) : Colors.white,
								borderRadius: BorderRadius.circular(12),
								border: Border.all(
									color: active
										? const Color(0xFF3A6FFF)
										: const Color(0xFFD7DDF0),
									width: active ? 1.5 : 1,
								),
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
										decoration: BoxDecoration(
											color: active
												? const Color(0xFF3A6FFF)
												: const Color(0xFFE9EDF7),
											borderRadius: BorderRadius.circular(999),
										),
										child: Text(
											title,
											style: TextStyle(
												fontSize: 13,
												fontWeight: FontWeight.bold,
												color: active ? Colors.white : const Color(0xFF5D6B8A),
											),
										),
									),
									const SizedBox(height: 8),
									Expanded(child: child),
								],
							),
						);
					}

					final screenWidth = MediaQuery.of(ctx).size.width;
					final isCompactLayout = screenWidth <= 700;

					Widget buildTransferControls({required bool compact}) {
						final controls = [
							SizedBox(
								width: compact ? 92 : 64,
								height: 38,
								child: ElevatedButton(
									onPressed: selectedRowIndex == null || selectedIsSplitList == true
											? null
											: () {
													moveSelectedOne();
											  },
									style: ElevatedButton.styleFrom(
										backgroundColor: const Color(0xFF3A6FFF),
										foregroundColor: Colors.white,
										padding: EdgeInsets.zero,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
									child: const Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.chevron_right, size: 24),
											Text(
												'1',
												style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							),
							SizedBox(
								width: compact ? 92 : 64,
								height: 38,
								child: ElevatedButton(
									onPressed: selectedRowIndex == null || selectedIsSplitList == false
											? null
											: () {
													moveSelectedOne();
											  },
									style: ElevatedButton.styleFrom(
										backgroundColor: const Color(0xFF3A6FFF),
										foregroundColor: Colors.white,
										padding: EdgeInsets.zero,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
									child: const Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.chevron_left, size: 24),
											Text(
												'1',
												style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							),
							SizedBox(
								width: compact ? 92 : 64,
								height: 38,
								child: ElevatedButton(
									onPressed: selectedRowIndex == null || selectedIsSplitList == true
											? null
											: () {
													moveSelectedAll();
											  },
									style: ElevatedButton.styleFrom(
										backgroundColor: const Color(0xFF3A6FFF),
										foregroundColor: Colors.white,
										padding: EdgeInsets.zero,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
									child: const Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.chevron_right, size: 24),
											Text(
												'Alle',
												style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							),
							SizedBox(
								width: compact ? 92 : 64,
								height: 38,
								child: ElevatedButton(
									onPressed: selectedRowIndex == null || selectedIsSplitList == false
											? null
											: () {
													moveSelectedAll();
											  },
									style: ElevatedButton.styleFrom(
										backgroundColor: const Color(0xFF3A6FFF),
										foregroundColor: Colors.white,
										padding: EdgeInsets.zero,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
									child: const Row(
										mainAxisAlignment: MainAxisAlignment.center,
										children: [
											Icon(Icons.chevron_left, size: 24),
											Text(
												'Alle',
												style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
											),
										],
									),
								),
							),
						];

						if (compact) {
							return SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: [
										for (var i = 0; i < controls.length; i++) ...[
											if (i > 0) const SizedBox(width: 8),
											controls[i],
										],
									],
								),
							);
						}

						return Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								for (var i = 0; i < controls.length; i++) ...[
									if (i > 0) const SizedBox(height: 10),
									controls[i],
								],
							],
						);
					}

					return AlertDialog(
						insetPadding: isCompactLayout
								? const EdgeInsets.symmetric(horizontal: 8, vertical: 16)
								: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
						shape:
								RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
						titlePadding: EdgeInsets.zero,
						title: Container(
							padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
							decoration: const BoxDecoration(
								color: Color(0xFF3A6FFF),
								borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
							),
							child: Row(
								children: [
									const Icon(Icons.call_split, color: Colors.white, size: 20),
									const SizedBox(width: 8),
									Text(
										'Rechnung teilen - Tisch: $placeName',
										style: const TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.bold,
											fontSize: 15,
										),
									),
								],
							),
						),
						content: SizedBox(
							width: isCompactLayout ? screenWidth * 0.92 : 640,
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									const SizedBox(height: 4),
									ConstrainedBox(
										constraints: BoxConstraints(maxHeight: isCompactLayout ? 520 : 380),
										child: isCompactLayout
												? Column(
													children: [
														Expanded(
															child: buildListSection(
																title: 'alle Buchungen',
																active: selectedIsSplitList != true,
																child: ListView.separated(
																		itemCount: lines.length,
																		separatorBuilder: (_, __) => const Divider(height: 1),
																		itemBuilder: (_, index) {
																			final line = lines[index];
																			final remainingQty =
																					line.qty - splitQuantities[index];
																			if (remainingQty == 0) {
																				return const SizedBox.shrink();
																			}
																			return buildLineTile(
																				index: index,
																				line: line,
																				qty: remainingQty,
																				selected: isRowSelected(index, false),
																				onSelect: () {
																					setDialogState(() {
																						if (isRowSelected(index, false)) {
																							selectedRowIndex = null;
																							selectedIsSplitList = null;
																						} else {
																							selectedRowIndex = index;
																							selectedIsSplitList = false;
																						}
																					});
																				},
																			);
																		},
																),
															),
														),
														const SizedBox(height: 10),
														SizedBox(height: 40, child: buildTransferControls(compact: true)),
														const SizedBox(height: 10),
														Expanded(
															child: buildListSection(
																title: 'aufgeteilte Buchung',
																active: selectedIsSplitList == true,
																child: ListView.separated(
																		itemCount: lines.length,
																		separatorBuilder: (_, __) => const Divider(height: 1),
																		itemBuilder: (_, index) {
																			final line = lines[index];
																			final splitQty = splitQuantities[index];
																			if (splitQty == 0) {
																				return const SizedBox.shrink();
																			}
																			return buildLineTile(
																				index: index,
																				line: line,
																				qty: splitQty,
																				selected: isRowSelected(index, true),
																				onSelect: () {
																					setDialogState(() {
																						if (isRowSelected(index, true)) {
																							selectedRowIndex = null;
																							selectedIsSplitList = null;
																						} else {
																							selectedRowIndex = index;
																							selectedIsSplitList = true;
																						}
																					});
																				},
																			);
																		},
																),
															),
														),
													],
												)
												: Row(
													children: [
														Expanded(
															child: buildListSection(
																title: 'alle Buchungen',
																active: selectedIsSplitList != true,
																child: ListView.separated(
																	itemCount: lines.length,
																	separatorBuilder: (_, __) => const Divider(height: 1),
																	itemBuilder: (_, index) {
																		final line = lines[index];
																		final remainingQty =
																				line.qty - splitQuantities[index];
																		if (remainingQty == 0) {
																			return const SizedBox.shrink();
																		}
																		return buildLineTile(
																			index: index,
																			line: line,
																			qty: remainingQty,
																			selected: isRowSelected(index, false),
																			onSelect: () {
																				setDialogState(() {
																					if (isRowSelected(index, false)) {
																						selectedRowIndex = null;
																						selectedIsSplitList = null;
																					} else {
																						selectedRowIndex = index;
																						selectedIsSplitList = false;
																					}
																				});
																			},
																		);
																	},
														),
													),
												),
												const SizedBox(width: 12),
												buildTransferControls(compact: false),
												const SizedBox(width: 12),
												Expanded(
													child: buildListSection(
														title: 'aufgeteilte Buchung',
														active: selectedIsSplitList == true,
														child: ListView.separated(
																	itemCount: lines.length,
																	separatorBuilder: (_, __) => const Divider(height: 1),
																	itemBuilder: (_, index) {
																		final line = lines[index];
																		final splitQty = splitQuantities[index];
																		if (splitQty == 0) {
																			return const SizedBox.shrink();
																		}
																		return buildLineTile(
																			index: index,
																			line: line,
																			qty: splitQty,
																			selected: isRowSelected(index, true),
																			onSelect: () {
																				setDialogState(() {
																					if (isRowSelected(index, true)) {
																						selectedRowIndex = null;
																						selectedIsSplitList = null;
																					} else {
																						selectedRowIndex = index;
																						selectedIsSplitList = true;
																					}
																				});
																			},
																		);
																	},
														),
													),
														),
											],
										),
									),
									const Divider(height: 16, thickness: 1.5),
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										children: [
											const Text(
												'aktuelle Rechnung',
												style: TextStyle(
														fontSize: 20, fontWeight: FontWeight.bold),
											),
											Text(
												'€${splitTotal.toStringAsFixed(2)}',
												style: const TextStyle(
													fontSize: 20,
													fontWeight: FontWeight.bold,
													color: Color(0xFF3A6FFF),
												),
											),
										],
									),
									const SizedBox(height: 4),
									Row(
										mainAxisAlignment: MainAxisAlignment.spaceBetween,
										children: [
											const Text(
												'verbleibende Rechnung',
												style: TextStyle(
														fontSize: 12, fontWeight: FontWeight.bold),
											),
											Text(
												'€${remainingTotal.toStringAsFixed(2)}',
												style: const TextStyle(
													fontSize: 12,
													fontWeight: FontWeight.bold,
													color: Color(0xFF1A237E),
												),
											),
										],
									),
								],
							),
						),
						actionsPadding:
								const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
						actions: [
							TextButton(
								onPressed: () => Navigator.of(ctx).pop(),
								child: const Text('Abbrechen'),
							),
							ElevatedButton.icon(
								style: ElevatedButton.styleFrom(
									backgroundColor: const Color(0xFF3A6FFF),
									foregroundColor: Colors.white,
									shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8)),
								),
								icon: const Icon(Icons.check, size: 18),
								label: const Text('Kassieren'),
								onPressed: splitTotal == 0
										? null
										: () async {
													final splitOrderItem = OrderItem(
														id: 0,
														id_: 'split-checkout',
														tickettype: 0,
														ticketId: 0,
														lines: splitLines,
													);

											final confirmed = await CheckoutDialog.show(
											  context: ctx,
												orderitem: splitOrderItem,
												placeName: placeName,
											);

									    if (!confirmed) {
										    return;
									    }
											final originalLines = List<OrderLine>.from(lines);
											final updatedLines = <OrderLine>[];

											for (var index = 0; index < originalLines.length; index++) {
												final line = originalLines[index];
												final splitQty = splitQuantities[index];
												final remainingQty = line.qty - splitQty;

												if (remainingQty <= 0) {
													continue;
												}

												updatedLines.add(OrderLine(
													id: line.id,
													orderId: line.orderId,
													productId: line.productId,
													productName: line.productName,
													pricesell: line.pricesell,
													qty: remainingQty,
													attSetInstDesc: line.attSetInstDesc,
													qtyNew: 0,
													attributes: line.attributes,
												));
											}

											orderitem.lines
												..clear()
												..addAll(updatedLines);

											Navigator.of(ctx).pop(splitTotal);
										},
							),
						],
					);
				},
			),
		);
	}
}

