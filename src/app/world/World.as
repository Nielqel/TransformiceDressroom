package app.world
{
	import com.adobe.images.*;
	import com.piterwilson.utils.*;
	import com.fewfre.utils.AssetManager;
	import com.fewfre.display.*;
	import com.fewfre.events.*;
	import com.fewfre.utils.*;

	import app.ui.*;
	import app.ui.screens.*;
	import app.ui.buttons.*;
	import app.ui.common.*;
	import app.data.*;
	import app.world.data.*;
	import app.world.elements.*;

	import flash.display.*;
	import flash.text.*;
	import flash.events.*
	import flash.external.*;
	import flash.geom.*;
	import flash.net.*;
	import flash.utils.*;
	import app.ui.panes.*;
	import app.ui.panes.colorpicker.ColorPickerTabPane;
	import flash.display.MovieClip;
	import flash.ui.Keyboard;
	
	public class World extends MovieClip
	{
		// Storage
		private var character		: Character;
		private var _paneManager	: PaneManager;

		private var shopTabs		: ShopTabList;
		private var _toolbox		: Toolbox;
		private var linkTray		: LinkTray;
		private var trashConfirmScreen	: TrashConfirmScreen;
		private var _langScreen	: LangScreen;

		private var button_hand	: PushButton;
		private var button_back	: PushButton;
		private var button_backHand: PushButton;

		private var currentlyColoringType:ItemType=null;
		private var configCurrentlyColoringType:String;
		
		private var _itemFiltering_filterEnabled : Boolean = false;
		private var _itemFiltering_selectionModeOn : Boolean = false;
		private var _giantFilterIcon : Sprite;
		
		// Constants
		public static const COLOR_PANE_ID:String = "colorPane";
		public static const TAB_OTHER:String = "other";
		public static const TAB_CONFIG:String = "config";
		public static const TAB_OUTFITS:String = "outfits";
		public static const TAB_ITEM_FILTERING:String = "filtering";
		public static const CONFIG_COLOR_PANE_ID:String = "configColorPane";
		public static const COLOR_FINDER_PANE_ID:String = "colorFinderPane";
		public static const WORN_ITEMS_PANE_ID:String = "WORN_ITEMS_PANE_ID";
		
		// Constructor
		public function World(pStage:Stage) {
			super();
			ConstantsApp.CONFIG_TAB_ENABLED = !!Fewf.assets.getData("config").username_lookup_url;
			ConstantsApp.ANIMATION_DOWNLOAD_ENABLED = !!Fewf.assets.getData("config").spritesheet2gif_url && (Fewf.isExternallyLoaded || (ExternalInterface.available && ExternalInterface.call("eval", "window.location.href") == null));
			_buildWorld(pStage);
			pStage.addEventListener(MouseEvent.MOUSE_WHEEL, _onMouseWheel);
			pStage.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDownListener);
		}
		
		private function _buildWorld(pStage:Stage) {
			ShareCodeFilteringData.init();
			
			/****************************
			* Create Character
			*****************************/
			var parms:String = null;
			if(!Fewf.isExternallyLoaded) {
				try {
					var urlPath:String = ExternalInterface.call("eval", "window.location.href");
					if(urlPath && urlPath.indexOf("?") > 0) {
						urlPath = urlPath.substr(urlPath.indexOf("?") + 1, urlPath.length);
					}
					parms = urlPath;
				} catch (error:Error) { };
			}
			
			_giantFilterIcon = new $FilterIcon();
			_giantFilterIcon.scaleX = _giantFilterIcon.scaleY = 4;
			_giantFilterIcon.x = 180; _giantFilterIcon.y = 180 + 50;
			addChild(_giantFilterIcon);
			_giantFilterIcon.visible = false;
			
			this.character = new Character(new <ItemData>[ GameAssets.defaultSkin, GameAssets.defaultPose ], parms)
				.setXY(180, 275).setDragBounds(0+4, 73+4, 375-8, Fewf.stage.stageHeight-73-8).appendTo(this);
			this.character.doubleClickEnabled = true;
			this.character.addEventListener(MouseEvent.DOUBLE_CLICK, function(e:MouseEvent){ _paneManager.openPane(WORN_ITEMS_PANE_ID); })
			
			/****************************
			* Setup UI
			*****************************/
			var tShop:RoundedRectangle = new RoundedRectangle({ x:450, y:10, width:ConstantsApp.SHOP_WIDTH, height:ConstantsApp.APP_HEIGHT })
				.appendTo(this).drawAsTray();
			_paneManager = tShop.addChild(new PaneManager()) as PaneManager;
			
			this.shopTabs = new ShopTabList(70, ConstantsApp.APP_HEIGHT).setXY(375, 10).appendTo(this);
			this.shopTabs.addEventListener(ShopTabList.TAB_CLICKED, _onTabClicked);
			_populateShopTabs();

			// Toolbox
			_toolbox = new Toolbox({
				character:character,
				onSave:_onSaveClicked, onAnimate:_onPlayerAnimationToggle, onRandomize:_onRandomizeDesignClicked,
				onTrash:_onTrashButtonClicked, onShare:_onShareButtonClicked, onScale:_onScaleSliderChange,
				onShareCodeEntered:_onShareCodeEntered, onItemFilterClosed:_onExitItemFilteringMode
			}).setXY(188, 28).appendTo(this);
			
			var tOutfitButton:ScaleButton = addChild(new ScaleButton({ x:_toolbox.x+167, y:_toolbox.y+12.5+21, width:25, height:25, origin:0.5, obj:new $Outfit(), obj_scale:0.4 })) as ScaleButton;
			tOutfitButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _paneManager.openPane(TAB_OUTFITS); });
			
			var tLangButton:LangButton = addChild(new LangButton({ x:22, y:pStage.stageHeight-17, width:30, height:25, origin:0.5 })) as LangButton;
			tLangButton.addEventListener(ButtonBase.CLICK, _onLangButtonClicked);
			
			new AppInfoBox().setXY(tLangButton.x+(tLangButton.Width*0.5)+(25*0.5)+2, pStage.stageHeight-17).appendTo(this);
			
			/****************************
			* Screens
			*****************************/
			linkTray = new LinkTray({ x:pStage.stageWidth * 0.5, y:pStage.stageHeight * 0.5 });
			linkTray.addEventListener(LinkTray.CLOSE, _onShareTrayClosed);
			
			trashConfirmScreen = new TrashConfirmScreen({ x:337, y:65 });
			trashConfirmScreen.addEventListener(TrashConfirmScreen.CONFIRM, _onTrashConfirmScreenConfirm);
			trashConfirmScreen.addEventListener(TrashConfirmScreen.CLOSE, _onTrashConfirmScreenClosed);
			
			_langScreen = new LangScreen({  });
			_langScreen.addEventListener(LangScreen.CLOSE, _onLangScreenClosed);

			/****************************
			* Create item panes
			*****************************/
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) {
				_paneManager.addPane(tType.toString(), _setupItemPane(tType));
				if(tType != ItemType.POSE) {
					_paneManager.addPane("filter_"+tType.toString(), _setupItemPaneForFiltering(tType));
				}
				// Based on what the character is wearing at start, toggle on the appropriate buttons.
				getTabByType(tType).toggleGridButtonWithData( character.getItemData(tType) );
			}
			
			/****************************
			* Config Pane
			*****************************/
			if(ConstantsApp.CONFIG_TAB_ENABLED) {
				_paneManager.addPane(TAB_CONFIG, new ConfigTabPane({
					onShareCodeEntered:_onShareCodeEntered,
					onUserLookClicked:_useOutfitShareCode
				}));
			}
			
			/****************************
			* Other Pane
			*****************************/
			var tPaneOther:OtherTabPane = _paneManager.addPane(TAB_OTHER, new OtherTabPane(character)) as OtherTabPane;
			tPaneOther.button_hand.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonHandClickAfter);
			for each(var bttn:Object in tPaneOther.buttons_back) {
				bttn.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonBackClickAfter);
			}
			tPaneOther.button_backHand.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonBackHandClickAfter);
			tPaneOther.shamanColorPickerButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _shamanColorButtonClicked(); });
			tPaneOther.shamanColorBlueButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _setConfigShamanColor(0x95D9D6); });
			tPaneOther.shamanColorPinkButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _setConfigShamanColor(0xFCA6F1); });
			tPaneOther.itemFilterButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _getAndOpenItemFilteringPane(); });
			tPaneOther = null;
			
			var tPane:TabPane = null;
			// Outfit Pane
			tPane = _paneManager.addPane(TAB_OUTFITS, new OutfitManagerTabPane(character, _useOutfitShareCode));
			tPane.infoBar.colorWheel.addEventListener(MouseEvent.MOUSE_UP, function(pEvent:Event){ _paneManager.openPane(shopTabs.getSelectedTabEventName()); });
			// Grid Management Events
			tPane.infoBar.rightItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(_paneManager.getPane(TAB_OUTFITS), true); });
			tPane.infoBar.leftItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(_paneManager.getPane(TAB_OUTFITS), false); });
			
			// "Other" Tab Color Picker Pane
			tPane = _paneManager.addPane(CONFIG_COLOR_PANE_ID, new ColorPickerTabPane({ hide_default:true }));
			tPane.addEventListener(ColorPickerTabPane.EVENT_COLOR_PICKED, _onConfigColorPickChanged);
			tPane.addEventListener(ColorPickerTabPane.EVENT_EXIT, function(pEvent:Event){ _paneManager.openPane(TAB_OTHER); });
			tPane.infoBar.hideImageCont();
			
			// Worn Items Pane
			tPane = _paneManager.addPane(WORN_ITEMS_PANE_ID, new WornItemsPane(character, _goToItem));
			tPane.infoBar.colorWheel.addEventListener(MouseEvent.MOUSE_UP, function(pEvent:Event){ _paneManager.openPane(TAB_OTHER); });
			
			// Item Filtering Pane
			tPane = _paneManager.addPane(TAB_ITEM_FILTERING, new ItemFilteringPane());
			tPane.addEventListener(ItemFilteringPane.EVENT_PREVIEW_ENABLED, function(pEvent:FewfEvent){ _enableFilterMode(); });
			tPane.addEventListener(ItemFilteringPane.EVENT_STOP_FILTERING, function(pEvent:FewfEvent){ _closeItemFilteringPane(); });
			tPane.addEventListener(ItemFilteringPane.EVENT_RESET_FILTERING, function(pEvent:FewfEvent){ _resetItemFilteringPane(); });
			
			// Color Picker Pane
			tPane = _paneManager.addPane(COLOR_PANE_ID, new ColorPickerTabPane({}));
			tPane.addEventListener(ColorPickerTabPane.EVENT_COLOR_PICKED, _onColorPickChanged);
			tPane.addEventListener(ColorPickerTabPane.EVENT_PREVIEW_COLOR, _onColorPickHoverPreview);
			tPane.addEventListener(ColorPickerTabPane.EVENT_EXIT, _onColorPickerBackClicked);
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(e){
				_onColorPickerBackClicked(e);
				_removeItem(_paneManager.getPane(COLOR_PANE_ID).infoBar.data.type);
			});
			
			// Color Finder Pane
			tPane = _paneManager.addPane(COLOR_FINDER_PANE_ID, new ColorFinderPane({}));
			tPane.addEventListener(ColorFinderPane.EVENT_EXIT, _onColorFinderBackClicked);
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(e){
				_onColorFinderBackClicked(e);
				_removeItem(_paneManager.getPane(COLOR_FINDER_PANE_ID).infoBar.data.type);
			});
			
			// Select First Pane
			shopTabs.tabs[0].toggleOn();
			
			tPane = null;
		}

		private function _setupItemPane(pType:ItemType) : ShopCategoryPane {
			var tPane:ShopCategoryPane = new ShopCategoryPane(pType);
			tPane.addEventListener(ShopCategoryPane.ITEM_TOGGLED, _onItemToggled);
			tPane.addEventListener(ShopCategoryPane.DEFAULT_SKIN_COLOR_BTN_CLICKED, function(){ _colorButtonClicked(pType); });
			tPane.addEventListener(ShopCategoryPane.FLAG_WAVE_CODE_CHANGED, function(e:FewfEvent){ character.flagWavingCode = e.data.code; });
			
			tPane.infoBar.colorWheel.addEventListener(ButtonBase.CLICK, function(){ _colorButtonClicked(pType); });
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(){ _removeItem(pType); });
			// Grid Management Events
			tPane.infoBar.randomizeButton.addEventListener(ButtonBase.CLICK, function(){ _randomItemOfType(pType); });
			tPane.infoBar.rightItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, true); });
			tPane.infoBar.leftItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, false); });
			// Misc
			if(tPane.infoBar.eyeDropButton) {
				tPane.infoBar.eyeDropButton.addEventListener(ButtonBase.CLICK, function(){ _eyeDropButtonClicked(pType); });
			}
			return tPane;
		}

		private function _setupItemPaneForFiltering(pType:ItemType) : ShopCategoryPaneForFiltering {
			var tPane:ShopCategoryPaneForFiltering = new ShopCategoryPaneForFiltering(pType);
			tPane.addEventListener(ShopCategoryPane.ITEM_TOGGLED, _onItemToggled);
			tPane.addEventListener(ShopCategoryPane.DEFAULT_SKIN_COLOR_BTN_CLICKED, function(){ _colorButtonClicked(pType); });
			
			// Grid Management Events
			tPane.infoBar.randomizeButton.addEventListener(ButtonBase.CLICK, function(){ _randomItemOfType(pType); });
			tPane.infoBar.rightItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, true); });
			tPane.infoBar.leftItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, false); });
			return tPane;
		}
		
		private function _shouldShowShopTab(type:ItemType) : Boolean {
			// Skin & pose have defaults, so always show - also need to list before other check since poses don't have filtering
			return type == ItemType.POSE || type == ItemType.SKIN
				|| !_itemFiltering_filterEnabled || ShareCodeFilteringData.getSelectedIds(type).length > 0;
		}
		
		private function _populateShopTabs() {
			var tabs:Vector.<Object>;
			if(_itemFiltering_selectionModeOn && !_itemFiltering_filterEnabled) {
				tabs = new <Object>[
					{ text:"tab_filtering", event:TAB_ITEM_FILTERING },
					{ text:"tab_furs", event:"filter_"+ItemType.SKIN.toString() },
					{ text:"tab_head", event:"filter_"+ItemType.HEAD.toString() },
					{ text:"tab_ears", event:"filter_"+ItemType.EARS.toString() },
					{ text:"tab_eyes", event:"filter_"+ItemType.EYES.toString() },
					{ text:"tab_mouth", event:"filter_"+ItemType.MOUTH.toString() },
					{ text:"tab_neck", event:"filter_"+ItemType.NECK.toString() },
					{ text:"tab_tail", event:"filter_"+ItemType.TAIL.toString() },
					{ text:"tab_hair", event:"filter_"+ItemType.HAIR.toString() },
					{ text:"tab_contacts", event:"filter_"+ItemType.CONTACTS.toString() },
					{ text:"tab_tattoo", event:"filter_"+ItemType.TATTOO.toString() },
					{ text:"tab_hand", event:"filter_"+ItemType.HAND.toString() }
				];
			} else {
				tabs = new Vector.<Object>();
				if(ConstantsApp.CONFIG_TAB_ENABLED && !_itemFiltering_filterEnabled) tabs.push({ text:"tab_config", event:TAB_CONFIG });
				
				for each(var type:ItemType in ItemType.TYPES_WITH_SHOP_PANES) {
					if(!_shouldShowShopTab(type)) continue;
					// Some i18n ids don't match the type string, so manually handling it here
					var i18nStr : String = type == ItemType.SKIN ? 'furs' : type == ItemType.HAND ? 'hand' : type == ItemType.POSE ? 'poses' : type.toString();
					tabs.push({ text:"tab_"+i18nStr, event:type.toString() });
				}
				tabs.push({ text:"tab_other", event:TAB_OTHER });
			}
			
			this.shopTabs.populate(tabs);
		}

		private function _onMouseWheel(pEvent:MouseEvent) : void {
			if(this.mouseX < this.shopTabs.x) {
				_toolbox.scaleSlider.updateViaMouseWheelDelta(pEvent.delta);
				character.scale = _toolbox.scaleSlider.value;
				_clampCharacterCoordsToSafeArea();
			}
		}

		private function _onKeyDownListener(e:KeyboardEvent) : void {
			if (e.keyCode == Keyboard.RIGHT){
				_traversePaneButtonGrid(_paneManager.getOpenPane(), true);
			}
			else if (e.keyCode == Keyboard.LEFT) {
				_traversePaneButtonGrid(_paneManager.getOpenPane(), false);
			}
			else if (e.keyCode == Keyboard.UP){
				_traversePaneButtonGridVertically(_paneManager.getOpenPane(), true);
			}
			else if (e.keyCode == Keyboard.DOWN) {
				_traversePaneButtonGridVertically(_paneManager.getOpenPane(), false);
			}
		}
		
		private function _traversePaneButtonGrid(pane:TabPane, pRight:Boolean):void {
			if(pane && pane.grid && pane.buttons && pane.buttons.length > 0 && pane.buttons[0] is PushButton) {
				var buttons:Array = pane.buttons;
				var activeButtonIndex:int = _findIndexActivePushButton(buttons);
				if(activeButtonIndex == -1) { activeButtonIndex = pane.grid.reversed ? buttons.length-1 : 0; }
				
				var dir:int = (pRight ? 1 : -1) * (pane.grid.reversed ? -1 : 1),
					length:uint = buttons.length;
					
				var newI:int = activeButtonIndex+dir;
				// mod it so it wraps - `length` added before mod to allow a `-1` dir to properly wrap
				newI = (length + newI) % length;
				
				var btn:PushButton = buttons[newI];
				btn.toggleOn();
				pane.scrollItemIntoView(btn);
			}
		}
		
		private function _traversePaneButtonGridVertically(pane:TabPane, pUp:Boolean):void {
			if(pane && pane is ColorPickerTabPane) {
				(pane as ColorPickerTabPane).nextSwatch(!pUp);
			}
			else if(pane && pane.grid && pane.buttons && pane.buttons.length > 0 && pane.buttons[0] is PushButton) {
				var buttons:Array = pane.buttons, grid:Grid = pane.grid;
				
				var activeButtonIndex:int = _findIndexActivePushButton(buttons);
				if(activeButtonIndex == -1) { activeButtonIndex = grid.reversed ? buttons.length-1 : 0; }
				var dir:int = (pUp ? -1 : 1) * (grid.reversed ? -1 : 1),
					length:uint = buttons.length;
				
				var rowI:Number = Math.floor(activeButtonIndex / grid.columns);
				rowI = (rowI + dir); // increment row in direction
				rowI = (grid.rows + rowI) % grid.rows; // wrap it in both directions
				var colI = activeButtonIndex % grid.columns;
				
				// we want to stay in the same column, and just move up/down a row
				// var newRowI:Number = (grid.rows + rowI) % grid.rows;
				var newI:int = rowI*grid.columns + colI;
				
				// since row is modded, it can only ever be out of bounds at the end - this happens if the last
				// row doesn't have enough items to fill all columns, and active column is in one of them.
				if(newI >= length) {
					// we solve it by going an extra step in our current direction, mod it again so it can wrap if needed,
					// and then we recalculate the button i
					rowI += dir;
					rowI = (grid.rows + rowI) % grid.rows; // wrap it again
					newI = rowI*grid.columns + colI;
				}
				
				var btn:PushButton = buttons[newI];
				btn.toggleOn();
				pane.scrollItemIntoView(btn);
			}
		}
		
		// Find the pressed button
		private function _findIndexActivePushButton(pButtons:Array):int {
			for(var i:int = 0; i < pButtons.length; i++){
				if((pButtons[i] as PushButton).pushed){
					return i;
				}
			}
			return -1;
		}

		private function _onScaleSliderChange(pEvent:Event):void {
			character.scale = _toolbox.scaleSlider.value;
			_clampCharacterCoordsToSafeArea();
		}
		
		private function _clampCharacterCoordsToSafeArea() : void {
			character.x = Math.max(character.dragBounds.x, Math.min(character.dragBounds.right, character.x));
			character.y = Math.max(character.dragBounds.y, Math.min(character.dragBounds.bottom, character.y));
		}

		private function _onShareCodeEntered(code:String, pProgressCallback:Function):void {
			if(!code || code == "") { return; pProgressCallback("placeholder"); }
			
			try {
				pProgressCallback("loading");
				_useUnknownShareCode(code, function(parseSuccess){
					// Now tell code box that we are done
					pProgressCallback(parseSuccess ? "success" : "invalid");
				});
			}
			catch (error:Error) {
				pProgressCallback("invalid");
			};
		}
		private function _useUnknownShareCode(code:String, callback:Function) : void {
			code = FewfUtils.trim(code);
			if(ShareCodeFilteringData.isValidCode(code)) {
				_useItemFilterShareCode(code, callback);
			} else {
				callback( _useOutfitShareCode(code) );
			}
		}
		
		private function _useOutfitShareCode(code:String) : Boolean {
			code = FewfUtils.trim(code);
			if(code.indexOf("?") > -1) {
				code = code.substr(code.indexOf("?") + 1, code.length);
			}
		
			// First remove old stuff to prevent conflicts
			character.shamanMode = ShamanMode.OFF;
			for each(var tType:ItemType in ItemType.LAYERING) { _removeItem(tType); }
			_removeItem(ItemType.POSE);
			
			var parseSuccess:Boolean = character.parseParams(code);
			
			character.updatePose();
			
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) { _refreshButtonCustomizationForItemData(character.getItemData(tType)); }
			
			// now update the infobars
			_updateUIBasedOnCharacter();
			(_paneManager.getPane(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
			
			return parseSuccess;
		}
		
		private function _useItemFilterShareCode(code:String, callback:Function) : void {
			code = FewfUtils.trim(code);
			
			var pastebinKey = ShareCodeFilteringData.checkIfPastebin(code);
			if(pastebinKey) {
				var fetchpastebin_url:String = Fewf.assets.getData("config").fetchpastebin_url;
				if(!fetchpastebin_url) { callback(false); return; }
				
				var url:String = fetchpastebin_url+"?key="+pastebinKey;
				Fewf.assets.loadWithCallback([ [url, { type:"txt", name:pastebinKey }] ], function():void{
					_useItemFilterShareCode(Fewf.assets.getData(pastebinKey), callback);
				});
				return;
			}
		
			// First remove old stuff to prevent conflicts
			character.shamanMode = ShamanMode.OFF;
			for each(var tType:ItemType in ItemType.LAYERING) { _removeItem(tType); }
			_removeItem(ItemType.POSE);
			
			// If selection mode is active, end it
			_itemFiltering_selectionModeOn = false;
			_showOrHideGiantFilterIcon();
			
			// Parse actual code
			var parseSuccess:Boolean = ShareCodeFilteringData.parseShareCode(code);
			if(parseSuccess) {
				_enableFilterMode();
				
				character.updatePose();
				
				for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) { _refreshButtonCustomizationForItemData(character.getItemData(tType)); }
				
				// now update the infobars
				_updateUIBasedOnCharacter();
				(_paneManager.getPane(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
			}
			
			callback(parseSuccess);
		}
		
		// Enables it using data already in ShareCodeFilteringData
		private function _enableFilterMode() : void {
			_itemFiltering_filterEnabled = true;
			_toolbox.showItemFilterBanner();
			_populateShopTabs();
			_updateAllShopPaneFilters();
			_showOrHideGiantFilterIcon();
			// Select first tab available
			shopTabs.tabs[0].toggleOn();
		}
		
		private function _onExitItemFilteringMode(e:Event) : void { _exitFilterMode(); };
		private function _exitFilterMode() : void {
			_itemFiltering_filterEnabled = false;
			_toolbox.hideItemFilterBanner();
			_populateShopTabs();
			_clearItemFiltering();
			_showOrHideGiantFilterIcon();
			// Select first tab available (needed since tabs repopulated)
			shopTabs.tabs[0].toggleOn();
		}
		
		private function _updateAllShopPaneFilters() : void {
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHARE_FILTER_PANES) {
				// Remove encase existing item is a filtered one
				_removeItem(tType);
				
				var ids : Vector.<String> = ShareCodeFilteringData.getSelectedIds(tType).concat();
				if(tType == ItemType.SKIN && ids.length == 0) {
					ids.push(GameAssets.defaultSkin.id);
				}
				getTabByType(tType).filterItemIds(ids);
				// Remove everything again to make sure "defaults" are correctly selected (ex: if fur 0 isn't a selected one)
				_removeItem(tType);
			}
		}
		
		private function _clearItemFiltering() : void {
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) {
				getTabByType(tType).filterItemIds(null);
			}
		}
		
		private function _dirtyAllItemFilteringPanes() : void {
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHARE_FILTER_PANES) {
				var pane:ShopCategoryPaneForFiltering = _paneManager.getPane("filter_"+tType.toString()) as ShopCategoryPaneForFiltering;
				pane.dirtyMe();
			}
		}
		
		private function _showOrHideGiantFilterIcon() : void {
			_giantFilterIcon.visible = _itemFiltering_selectionModeOn && !_itemFiltering_filterEnabled;
			character.visible = !_giantFilterIcon.visible;
		}

		private function _onPlayerAnimationToggle(pEvent:Event):void {
			character.animatePose = !character.animatePose;
			if(character.animatePose) {
				character.outfit.play();
			} else {
				character.outfit.stop();
			}
			_toolbox.toggleAnimateButtonAsset(character.animatePose);
		}

		private function _onSaveClicked(pEvent:Event) : void {
			if(ConstantsApp.ANIMATION_DOWNLOAD_ENABLED && character.animatePose) {
				// FewfDisplayUtils.saveAsSpriteSheet(this.character.copy().outfit.pose, "spritesheet", this.character.outfit.scaleX);
				_toolbox.downloadButton.disable();
				FewfDisplayUtils.saveAsAnimatedGif(this.character.copy().outfit.pose, "character", this.character.outfit.scaleX, null, function(){
					_toolbox.downloadButton.enable();
				});
			} else {
				FewfDisplayUtils.saveAsPNG(this.character, "character");
			}
		}

		// Note: does not automatically de-select previous buttons / infobars; do that before calling this
		// This function is required when setting data via parseParams
		private function _updateUIBasedOnCharacter() : void {
			var tPane:ShopCategoryPane;
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) {
				tPane = getTabByType(tType);
				// Based on what the character is wearing at start, toggle on the appropriate buttons.
				tPane.toggleGridButtonWithData( character.getItemData(tType) );
			}
			getTabByType(ItemType.POSE).flagWaveInput.text = character.flagWavingCode || "";
		}

		private function _onItemToggled(pEvent:FewfEvent) : void {
			var tType:ItemType = pEvent.data.type;
			var tInfoBar:ShopInfoBar = getInfoBarByType(tType);

			// De-select all buttons that aren't the clicked one.
			var tPane:ShopCategoryPane = getTabByType(tType);
			var tButtons:Array = tPane.buttons;
			for(var i:int = 0; i < tButtons.length; i++) {
				if(tButtons[i].data.itemID != pEvent.data.itemID) {
					if (tButtons[i].pushed) { tButtons[i].toggleOff(); }
				}
			}

			var tButton:PushButton = tPane.getButtonWithItemData(pEvent.data.itemData);
			// If clicked button is toggled on, equip it. Otherwise remove it.
			if(tButton.pushed) {
				var tData:ItemData = GameAssets.getItemFromTypeID(tType, pEvent.data.itemID);
				setCurItemID(tType, tButton.id);
				this.character.setItemData(tData);

				tInfoBar.addInfo( tData, GameAssets.getColoredItemImage(tData) );
				var showColorWheel : Boolean = false;
				if(GameAssets.getNumOfCustomColors(tButton.Image as MovieClip) > 0) {
					showColorWheel = true;
					if(_itemFiltering_filterEnabled) {
						showColorWheel = ShareCodeFilteringData.isCustomizable(tType, tData.id);
					}
				}
				tInfoBar.showColorWheel(showColorWheel);
			} else {
				_removeItem(tType);
			}
		}

		public function buttonHandClickAfter(pEvent:Event):void {
			toggleItemSelectionOneOff(ItemType.OBJECT, pEvent.target as PushButton, GameAssets.extraObjectWand);
		}

		public function buttonBackClickAfter(pEvent:FewfEvent):void {
			for each(var bttn:PushButton in (_paneManager.getPane(TAB_OTHER) as OtherTabPane).buttons_back) {
				if(bttn.data.id != pEvent.data.id) bttn.toggleOff(false);
			}
			toggleItemSelectionOneOff(ItemType.BACK, pEvent.target as PushButton, GameAssets.getItemFromTypeID(ItemType.BACK, pEvent.data.id));
		}

		public function buttonBackHandClickAfter(pEvent:Event):void {
			toggleItemSelectionOneOff(ItemType.PAW_BACK, pEvent.target as PushButton, GameAssets.extraBackHand);
		}

		private function toggleItemSelectionOneOff(pType:ItemType, pButton:PushButton, pItemData:ItemData) : void {
			if (pButton.pushed) {
				this.character.setItemData( pItemData );
			} else {
				this.character.removeItem(pType);
			}
		}

		private function _removeItem(pType:ItemType) : void {
			if(pType == ItemType.BACK || pType == ItemType.PAW_BACK || pType == ItemType.OBJECT) {
				this.character.removeItem(pType);
			}
			var tTabPane:ShopCategoryPane = getTabByType(pType);
			if(!tTabPane || tTabPane.infoBar.hasData == false) { return; }

			// If item has a default value, toggle it on. otherwise remove item.
			if(!!tTabPane.defaultItemData) {
				tTabPane.getButtonWithItemData(tTabPane.defaultItemData).toggleOn();
			} else {
				this.character.removeItem(pType);
				tTabPane.infoBar.removeInfo();
				tTabPane.buttons[ tTabPane.selectedButtonIndex ].toggleOff();
			}
		}
		
		private function _onTabClicked(pEvent:FewfEvent) : void {
			_paneManager.openPane(pEvent.data.toString());
		}

		private function _onRandomizeDesignClicked(pEvent:Event) : void {
			for each(var tType:ItemType in ItemType.TYPES_WITH_SHOP_PANES) {
				var odds:Number = tType == ItemType.POSE ? 0.5 : 0.65;
				_randomItemOfType(tType, Math.random() <= odds);
			}
			(_paneManager.getPane(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
		}

		private function _randomItemOfType(pType:ItemType, pSetToDefault:Boolean=false) : void {
			var pane:ShopCategoryPane = getTabByType(pType);
			if(pane.infoBar.isRefreshLocked || !pane.buttons.length) { return; }
			
			if(!pSetToDefault) {
				var tLength = pane.buttons.length;
				var btn = pane.buttons[ Math.floor(Math.random() * tLength) ];
				btn.toggleOn();
				if(pane.flagOpen) pane.scrollItemIntoView(btn);
			} else {
				_removeItem(pType);
				// Set to default values for required types
				if(!!pane.defaultItemData) {
					if(pane.flagOpen) pane.scrollItemIntoView(pane.getButtonWithItemData(pane.defaultItemData));
				}
			}
		}
		
		private function _goToItem(pItemData:ItemData) : void {
			var itemType:ItemType = pItemData.type;
			
			shopTabs.UnpressAll();
			shopTabs.toggleTabOn(itemType.toString());
			var tPane:ShopCategoryPane = getTabByType(itemType);
			var itemBttn:PushButton = tPane.toggleGridButtonWithData( character.getItemData(itemType) );
			tPane.scrollItemIntoView(itemBttn);
		}
		
		private function _onShareButtonClicked(pEvent:Event) : void {
			var tURL = "", tOfficialCode = "";
			try {
				if(Fewf.isExternallyLoaded) {
					tURL = this.character.getParams();
				} else {
					tURL = ExternalInterface.call("eval", "window.location.origin+window.location.pathname");
					tURL += "?"+this.character.getParams();
				}
			} catch (error:Error) {
				tURL = "<error creating link>";
			};
			
			try {
				tOfficialCode = this.character.getParamsTfmOfficialSyntax();
			} catch (error:Error) {
				tOfficialCode = "<error creating link>";
			};

			linkTray.open(tURL, tOfficialCode);
			addChild(linkTray);
		}

		private function _onShareTrayClosed(pEvent:Event) : void {
			removeChild(linkTray);
		}

		private function _onTrashButtonClicked(pEvent:Event) : void {
			addChild(trashConfirmScreen);
		}

		private function _onTrashConfirmScreenConfirm(pEvent:Event) : void {
			removeChild(trashConfirmScreen);
			character.shamanMode = ShamanMode.OFF;
			// Remove items
			for each(var tItem in ItemType.LAYERING) { _removeItem(tItem); }
			_removeItem(ItemType.POSE);
			
			// Refresh panes
			for each(var tItem in ItemType.TYPES_WITH_SHOP_PANES) {
				var pane:ShopCategoryPane = getTabByType(tItem);
				pane.infoBar.unlockRandomizeButton();
				
				// Reset customizations
				if(tItem != ItemType.POSE) {
					var dataList:Vector.<ItemData> = GameAssets.getItemDataListByType(tItem);
					
					for(var i:int = 0; i < dataList.length; i++){
						if(dataList[i].hasModifiedColors()) {
							dataList[i].setColorsToDefault();
							_refreshButtonCustomizationForItemData(dataList[i]);
						}
					}
				}
				
			}
			(_paneManager.getPane(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
		}

		private function _onTrashConfirmScreenClosed(pEvent:Event) : void {
			removeChild(trashConfirmScreen);
		}

		private function _onLangButtonClicked(pEvent:Event) : void {
			_langScreen.open();
			addChild(_langScreen);
		}

		private function _onLangScreenClosed(pEvent:Event) : void {
			removeChild(_langScreen);
		}

		//{REGION Get TabPane data
			private function getTabByType(pType:ItemType) : ShopCategoryPane {
				return _paneManager.getPane(pType.toString()) as ShopCategoryPane;
			}

			private function getInfoBarByType(pType:ItemType) : ShopInfoBar {
				return getTabByType(pType).infoBar;
			}

			private function getButtonArrayByType(pType:ItemType) : Array {
				return getTabByType(pType).buttons;
			}

			private function getCurItemID(pType:ItemType) : int {
				return getTabByType(pType).selectedButtonIndex;
			}

			private function setCurItemID(pType:ItemType, pID:int) : void {
				getTabByType(pType).selectedButtonIndex = pID;
			}
		//}END Get TabPane data
		
		//{REGION ItemFiltering Tab
			private function _getAndOpenItemFilteringPane() : void {
				_itemFiltering_selectionModeOn = true;
				_exitFilterMode(); // If user is in filter mode but filter pane (thus going into selection mode), then exit filter mode
				_populateShopTabs();
				_dirtyAllItemFilteringPanes();
				_showOrHideGiantFilterIcon();
				shopTabs.toggleTabOn(TAB_ITEM_FILTERING);
			}
			private function _closeItemFilteringPane() : void {
				_itemFiltering_selectionModeOn = false;
				_clearItemFiltering();
				_populateShopTabs();
				_showOrHideGiantFilterIcon();
				shopTabs.toggleTabOn(TAB_OTHER);
			}
			private function _resetItemFilteringPane() : void {
				ShareCodeFilteringData.reset();
				_clearItemFiltering();
				_getAndOpenItemFilteringPane();
			}
		//}END ItemFiltering Tab

		//{REGION Color Tab
			private function _onColorPickChanged(e:FewfEvent):void {
				if(e.data.allUpdated) {
					this.character.getItemData(this.currentlyColoringType).colors = e.data.allColors;
				} else {
					this.character.getItemData(this.currentlyColoringType).colors[e.data.colorIndex] = uint(e.data.color);
				}
				_refreshSelectedItemColor(this.currentlyColoringType);
			}

			private function _onColorPickHoverPreview(pEvent:FewfEvent) : void {
				// Updated preview data
				GameAssets.swatchHoverPreviewData = pEvent.data;
				// refresh render for anything that uses it
				_refreshSelectedItemColor(this.currentlyColoringType);
			}
			
			private function _refreshSelectedItemColor(pType:ItemType) : void {
				character.updatePose();
				
				var tItemData = this.character.getItemData(pType);
				if(pType != ItemType.SKIN) {
					var tItem:MovieClip = GameAssets.getColoredItemImage(tItemData);
					GameAssets.copyColor(tItem, getButtonArrayByType(pType)[ getCurItemID(pType) ].Image );
					GameAssets.copyColor(tItem, getInfoBarByType( pType ).Image );
					GameAssets.copyColor(tItem, _paneManager.getPane(COLOR_PANE_ID).infoBar.Image);
				} else {
					_replaceImageWithNewImage(getButtonArrayByType(pType)[ getCurItemID(pType) ], GameAssets.getColoredItemImage(tItemData));
					_replaceImageWithNewImage(getInfoBarByType( pType ), GameAssets.getColoredItemImage(tItemData));
					_replaceImageWithNewImage(_paneManager.getPane(COLOR_PANE_ID).infoBar, GameAssets.getColoredItemImage(tItemData));
				}
				/*var tMC:MovieClip = this.character.getItemFromIndex(pType);
				if (tMC != null)
				{
					GameAssets.colorDefault(tMC);
					GameAssets.copyColor( tMC, getButtonArrayByType(pType)[ getCurItemID(pType) ].Image );
					GameAssets.copyColor(tMC, getInfoBarByType(pType).Image);
					GameAssets.copyColor(tMC, _paneManager.getPane(COLOR_PANE_ID).infoBar.Image);
					
				}*/
			}
			private function _replaceImageWithNewImage(pOldSource:Object, pNew:MovieClip) : void {
				pNew.x = pOldSource.Image.x;
				pNew.y = pOldSource.Image.y;
				pNew.scaleX = pOldSource.Image.scaleX;
				pNew.scaleY = pOldSource.Image.scaleY;
				pOldSource.Image.parent.addChild(pNew);
				pOldSource.Image.parent.removeChild(pOldSource.Image);
				pOldSource.Image = null;
				pOldSource.Image = pNew;
			}
			
			private function _refreshButtonCustomizationForItemData(data:ItemData) : void {
				if(!data || data.type == ItemType.POSE) { return; }
				
				var pane:ShopCategoryPane = getTabByType(data.type);
				var btn:PushButton = pane.getButtonWithItemData(data);
				
				
				if(data.type != ItemType.SKIN) {
					var tItem:MovieClip = GameAssets.getColoredItemImage(data);
					GameAssets.copyColor(tItem, btn.Image as MovieClip );
				} else {
					_replaceImageWithNewImage(btn, GameAssets.getColoredItemImage(data));
				}
			}

			private function _colorButtonClicked(pType:ItemType) : void {
				if(this.character.getItemData(pType) == null) { return; }

				var tData:ItemData = getInfoBarByType(pType).data;
				_paneManager.getPane(COLOR_PANE_ID).infoBar.addInfo( tData, GameAssets.getItemImage(tData) );
				this.currentlyColoringType = pType;
				(_paneManager.getPane(COLOR_PANE_ID) as ColorPickerTabPane).init( tData.colors, tData.defaultColors );
				_paneManager.openPane(COLOR_PANE_ID);
				_refreshSelectedItemColor(pType);
			}

			private function _onColorPickerBackClicked(pEvent:Event):void {
				_paneManager.openPane(_paneManager.getPane(COLOR_PANE_ID).infoBar.data.type.toString());
			}

			private function _eyeDropButtonClicked(pType:ItemType) : void {
				if(this.character.getItemData(pType) == null) { return; }

				var tData:ItemData = getInfoBarByType(pType).data;
				var tItem:MovieClip = GameAssets.getColoredItemImage(tData);
				var tItem2:MovieClip = GameAssets.getColoredItemImage(tData);
				_paneManager.getPane(COLOR_FINDER_PANE_ID).infoBar.addInfo( tData, tItem );
				this.currentlyColoringType = pType;
				(_paneManager.getPane(COLOR_FINDER_PANE_ID) as ColorFinderPane).setItem(tItem2);
				_paneManager.openPane(COLOR_FINDER_PANE_ID);
			}

			private function _onColorFinderBackClicked(pEvent:Event):void {
				_paneManager.openPane(_paneManager.getPane(COLOR_FINDER_PANE_ID).infoBar.data.type.toString());
			}

			private function _onConfigColorPickChanged(pEvent:FewfEvent):void {
				_setConfigShamanColor(uint(pEvent.data.color));
			}
			
			private function _setConfigShamanColor(val:uint) : void {
				/*_paneManager.getPane(TAB_OTHER).updateCustomColor(configCurrentlyColoringType, val);*/
				character.shamanColor = val;
				character.updatePose();
			}

			private function _shamanColorButtonClicked(/*pType:String, pColor:int*/) : void {
				/*this.configCurrentlyColoringType = pType;*/
				(_paneManager.getPane(CONFIG_COLOR_PANE_ID) as ColorPickerTabPane).init( new <uint>[ character.shamanColor ], null );
				_paneManager.openPane(CONFIG_COLOR_PANE_ID);
			}
		//}END Color Tab
	}
}
