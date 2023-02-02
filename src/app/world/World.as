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
	import app.data.*;
	import app.world.data.*;
	import app.world.elements.*;

	import fl.controls.*;
	import fl.events.*;
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
		internal var character		: Character;
		internal var _paneManager	: PaneManager;

		internal var shopTabs		: ShopTabContainer;
		internal var _toolbox		: Toolbox;
		internal var linkTray		: LinkTray;
		internal var trashConfirmScreen	: TrashConfirmScreen;
		internal var _langScreen	: LangScreen;

		internal var button_hand	: PushButton;
		internal var button_back	: PushButton;
		internal var button_backHand: PushButton;

		internal var currentlyColoringType:String="";
		internal var configCurrentlyColoringType:String;
		
		// Constants
		public static const COLOR_PANE_ID = "colorPane";
		public static const TAB_OTHER:String = "other";
		public static const TAB_CONFIG:String = "config";
		public static const TAB_OUTFITS:String = "outfits";
		public static const CONFIG_COLOR_PANE_ID = "configColorPane";
		public static const COLOR_FINDER_PANE_ID = "colorFinderPane";
		
		// Constructor
		public function World(pStage:Stage) {
			super();
			ConstantsApp.CONFIG_TAB_ENABLED = !!Fewf.assets.getData("config").username_lookup_url;
			_buildWorld(pStage);
			pStage.addEventListener(MouseEvent.MOUSE_WHEEL, _onMouseWheel);
			pStage.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDownListener);
		}
		
		private function _buildWorld(pStage:Stage) {
			GameAssets.init();
			
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

			this.character = addChild(new Character({ x:180, y:275,
				skin:GameAssets.skins[GameAssets.defaultSkinIndex],
				pose:GameAssets.poses[GameAssets.defaultPoseIndex],
				params:parms
			})) as Character;

			/****************************
			* Setup UI
			*****************************/
			var tShop:RoundedRectangle = addChild(new RoundedRectangle({ x:450, y:10, width:ConstantsApp.SHOP_WIDTH, height:ConstantsApp.APP_HEIGHT })) as RoundedRectangle;
			tShop.drawSimpleGradient(ConstantsApp.COLOR_TRAY_GRADIENT, 15, ConstantsApp.COLOR_TRAY_B_1, ConstantsApp.COLOR_TRAY_B_2, ConstantsApp.COLOR_TRAY_B_3);
			_paneManager = tShop.addChild(new PaneManager()) as PaneManager;
			
			var tabs:Array = [
				{ text:"tab_furs", event:ITEM.SKIN },
				{ text:"tab_head", event:ITEM.HAT },
				{ text:"tab_ears", event:ITEM.EARS },
				{ text:"tab_eyes", event:ITEM.EYES },
				{ text:"tab_mouth", event:ITEM.MOUTH },
				{ text:"tab_neck", event:ITEM.NECK },
				{ text:"tab_tail", event:ITEM.TAIL },
				{ text:"tab_hair", event:ITEM.HAIR },
				{ text:"tab_contacts", event:ITEM.CONTACTS },
				{ text:"tab_hand", event:ITEM.HAND },
				{ text:"tab_poses", event:ITEM.POSE },
				{ text:"tab_other", event:TAB_OTHER }
			];
			if(ConstantsApp.CONFIG_TAB_ENABLED) {
				tabs.unshift({ text:"tab_config", event:TAB_CONFIG });
			}
			this.shopTabs = addChild(new ShopTabContainer({ x:375, y:10, width:70, height:ConstantsApp.APP_HEIGHT, tabs:tabs })) as ShopTabContainer;
			this.shopTabs.addEventListener(ShopTabContainer.EVENT_SHOP_TAB_CLICKED, _onTabClicked);

			// Toolbox
			_toolbox = addChild(new Toolbox({
				x:188, y:28, character:character,
				onSave:_onSaveClicked, onAnimate:_onPlayerAnimationToggle, onRandomize:_onRandomizeDesignClicked,
				onTrash:_onTrashButtonClicked, onShare:_onShareButtonClicked, onScale:_onScaleSliderChange,
				onShareCodeEntered:_onShareCodeEntered
			})) as Toolbox;
			
			var tLangButton = addChild(new LangButton({ x:22, y:pStage.stageHeight-17, width:30, height:25, origin:0.5 }));
			tLangButton.addEventListener(ButtonBase.CLICK, _onLangButtonClicked);
			
			addChild(new AppInfoBox({ x:tLangButton.x+(tLangButton.Width*0.5)+(25*0.5)+2, y:pStage.stageHeight-17 }));
			
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
			* Create tabs and panes
			*****************************/
			var tPane = null;
			
			// Color Picker Pane
			tPane = _paneManager.addPane(COLOR_PANE_ID, new ColorPickerTabPane({}));
			tPane.addEventListener(ColorPickerTabPane.EVENT_COLOR_PICKED, _onColorPickChanged);
			tPane.addEventListener(ColorPickerTabPane.EVENT_DEFAULT_CLICKED, _onDefaultsButtonClicked);
			tPane.addEventListener(ColorPickerTabPane.EVENT_PREVIEW_COLOR, _onColorPickHoverPreview);
			tPane.addEventListener(ColorPickerTabPane.EVENT_EXIT, _onColorPickerBackClicked);
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(e){
				_onColorPickerBackClicked(e);
				_removeItem(_paneManager.getPane(COLOR_PANE_ID).infoBar.data.type);
			});

			// Create the panes
			var tTypes = [ ITEM.HAT, ITEM.HAIR, ITEM.EARS, ITEM.EYES, ITEM.MOUTH, ITEM.NECK, ITEM.TAIL, ITEM.HAND, ITEM.CONTACTS, ITEM.SKIN, ITEM.POSE ], tData:ItemData, tType:String;
			for(var i:int = 0; i < tTypes.length; i++) { tType = tTypes[i];
				tPane = _paneManager.addPane(tType, _setupPane(tType));
				// Based on what the character is wearing at start, toggle on the appropriate buttons.
				tData = character.getItemData(tType);
				if(tData) {
					var tIndex:int = FewfUtils.getIndexFromArrayWithKeyVal(GameAssets.getArrayByType(tType), "id", tData.id);
					tPane.buttons[ tIndex ].toggleOn();
				}
			}
			_paneManager.addPane(ITEM.SKIN_COLOR, _paneManager.getPane(ITEM.SKIN));
			
			/****************************
			* Config Pane
			*****************************/
			if(ConstantsApp.CONFIG_TAB_ENABLED) {
				tPane = _paneManager.addPane(TAB_CONFIG, new ConfigTabPane({
					onShareCodeEntered:_onShareCodeEntered,
					onUserLookClicked:_useShareCode
				}));
			}
			
			/****************************
			* Other Pane
			*****************************/
			tPane = _paneManager.addPane(TAB_OTHER, new OtherTabPane(character));
			tPane.button_hand.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonHandClickAfter);
			tPane.button_back.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonBackClickAfter);
			tPane.button_backHand.addEventListener(PushButton.STATE_CHANGED_AFTER, this.buttonBackHandClickAfter);
			tPane.shamanColorPickerButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _shamanColorButtonClicked(); });
			tPane.shamanColorBlueButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _setConfigShamanColor(0x95D9D6); });
			tPane.shamanColorPinkButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _setConfigShamanColor(0xFCA6F1); });
			tPane.outfitsButton.addEventListener(ButtonBase.CLICK, function(pEvent:Event){ _paneManager.openPane(TAB_OUTFITS); });
			
			// Outfit Pane
			tPane = _paneManager.addPane(TAB_OUTFITS, new OutfitManagerTabPane(character, _useShareCode));
			tPane.infoBar.colorWheel.addEventListener(MouseEvent.MOUSE_UP, function(pEvent:Event){ _paneManager.openPane(TAB_OTHER); });
			// Grid Management Events
			tPane.infoBar.rightItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(_paneManager.getPane(TAB_OUTFITS), true); });
			tPane.infoBar.leftItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(_paneManager.getPane(TAB_OUTFITS), false); });
			
			// "Other" Tab Color Picker Pane
			tPane = _paneManager.addPane(CONFIG_COLOR_PANE_ID, new ColorPickerTabPane({ hide_default:true }));
			tPane.addEventListener(ColorPickerTabPane.EVENT_COLOR_PICKED, _onConfigColorPickChanged);
			tPane.addEventListener(ColorPickerTabPane.EVENT_EXIT, function(pEvent:Event){ _paneManager.openPane(TAB_OTHER); });
			tPane.infoBar.hideImageCont();
			
			// Color Finder Pane
			tPane = _paneManager.addPane(COLOR_FINDER_PANE_ID, new ColorFinderPane({ }));
			tPane.addEventListener(ColorPickerTabPane.EVENT_EXIT, _onColorFinderBackClicked);
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(e){
				_onColorFinderBackClicked(e);
				_removeItem(_paneManager.getPane(COLOR_FINDER_PANE_ID).infoBar.data.type);
			});
			
			// Select First Pane
			shopTabs.tabs[0].toggleOn();
			
			tPane = null;
			tTypes = null;
			tData = null;
		}

		private function _setupPane(pType:String) : TabPane {
			var tPane:TabPane = new TabPane();
			tPane.addInfoBar( new ShopInfoBar({ showEyeDropButton:pType!=ITEM.POSE, showGridManagementButtons:true }) );
			_setupPaneButtons(pType, tPane, GameAssets.getArrayByType(pType));
			tPane.infoBar.colorWheel.addEventListener(ButtonBase.CLICK, function(){ _colorButtonClicked(pType); });
			tPane.infoBar.removeItemOverlay.addEventListener(MouseEvent.CLICK, function(){ _removeItem(pType); });
			// Grid Management Events
			tPane.infoBar.randomizeButton.addEventListener(ButtonBase.CLICK, function(){ _randomItemOfType(pType); });
			tPane.infoBar.reverseButton.addEventListener(ButtonBase.CLICK, function(){ _reverseGrid(pType); });
			tPane.infoBar.rightItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, true); });
			tPane.infoBar.leftItemButton.addEventListener(ButtonBase.CLICK, function(){ _traversePaneButtonGrid(tPane, false); });
			// Misc
			if(tPane.infoBar.eyeDropButton) {
				tPane.infoBar.eyeDropButton.addEventListener(ButtonBase.CLICK, function(){ _eyeDropButtonClicked(pType); });
			}
			return tPane;
		}

		private function _setupPaneButtons(pType:String, pPane:TabPane, pItemArray:Array) : void {
			var buttonPerRow = 6;
			var scale = 1;
			if(pType == ITEM.SKIN || pType == ITEM.POSE) {
					buttonPerRow = 5;
					scale = 1;
			}

			var grid:Grid = pPane.grid;
			if(!grid) { grid = pPane.addGrid( new Grid({ x:15, y:5, width:385, columns:buttonPerRow, margin:5 }) ); }
			grid.reset();

			var shopItem : MovieClip;
			var shopItemButton : PushButton;
			var i = -1;
			while (i < pItemArray.length-1) { i++;
				shopItem = GameAssets.getItemImage(pItemArray[i]);
				shopItem.scaleX = shopItem.scaleY = scale;

				shopItemButton = new PushButton({ width:grid.radius, height:grid.radius, obj:shopItem, id:i, data:{ type:pType, id:i } });
				grid.add(shopItemButton);
				pPane.buttons.push(shopItemButton);
				shopItemButton.addEventListener(PushButton.STATE_CHANGED_AFTER, _onItemToggled);
			}
			if(pType !== ITEM.POSE) {
				grid.reverse();
				_addDefaultSkinColorButtonIfSkinPane(pPane, pType);
			}
			pPane.UpdatePane();
		}
		
		private function _addDefaultSkinColorButtonIfSkinPane(pPane:TabPane, pType:String) {
			// Customizeable fur color button
			// cannot attach to button due to main button eating mouse events
			if(pType == ITEM.SKIN) {
				var tSkinButton = pPane.buttons[GameAssets.defaultSkinIndex];
				var tColorWheel = tSkinButton.parent.addChild(new ScaleButton({ x:tSkinButton.x + 60, y:tSkinButton.y + 12, obj:new $ColorWheel(), obj_scale:0.5 }));
				tColorWheel.addEventListener(ButtonBase.CLICK, function(){
					tSkinButton.toggleOn();
					_colorButtonClicked(pType);
				});
			}
		}

		private function _onMouseWheel(pEvent:MouseEvent) : void {
			if(this.mouseX < this.shopTabs.x) {
				_toolbox.scaleSlider.updateViaMouseWheelDelta(pEvent.delta);
				character.scale = _toolbox.scaleSlider.getValueAsScale();
			}
		}

		private function _onKeyDownListener(e:KeyboardEvent) : void {
			if (e.keyCode == Keyboard.RIGHT){
				_traversePaneButtonGrid(_paneManager.getOpenPane(), true);
			}
			else if (e.keyCode == Keyboard.LEFT) {
				_traversePaneButtonGrid(_paneManager.getOpenPane(), false);
			}
		}
		
		private function _traversePaneButtonGrid(pane:TabPane, pRight:Boolean):void {
			if(pane && pane.grid && pane.buttons && pane.buttons.length > 0 && pane.buttons[0] is PushButton) {
				var activeButtonIndex:int = 0;
				// Find the pressed button
				for(var i:int = 0; i < pane.buttons.length; i++){
					if((pane.buttons[i] as PushButton).pushed){
						activeButtonIndex = i;
						break;
					}
				}
				
				var dir:int = (pRight ? 1 : -1) * (pane.grid.reversed ? -1 : 1),
					length:uint = pane.buttons.length;
				
				// `length` added before mod to allow a `-1` dir to properly wrap
				var btn:PushButton = pane.buttons[(length+activeButtonIndex+dir) % length];
				btn.toggleOn();
				pane.scrollItemIntoView(btn);
			}
		}

		private function _onScaleSliderChange(pEvent:Event):void {
			character.scale = _toolbox.scaleSlider.getValueAsScale();
		}

		private function _onShareCodeEntered(pCode:String, pProgressCallback:Function):void {
			if(!pCode || pCode == "") { return; pProgressCallback("placeholder"); }
			
			try {
				_useShareCode(pCode);
				
				// Now tell code box that we are done
				pProgressCallback("success");
			}
			catch (error:Error) {
				pProgressCallback("invalid");
			};
		}
		
		private function _useShareCode(pCode:String):void {
			if(pCode.indexOf("?") > -1) {
				pCode = pCode.substr(pCode.indexOf("?") + 1, pCode.length);
			}
			
			// First remove old stuff to prevent conflicts
			GameAssets.shamanMode = SHAMAN_MODE.OFF;
			for each(var tItem in ITEM.LAYERING) { _removeItem(tItem); }
			_removeItem(ITEM.POSE);
			
			// Now update pose
			character.parseParams(pCode);
			character.updatePose();
			
			// now update the infobars
			_updateUIBasedOnCharacter();
			(getTabByType(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
		}

		private function _onPlayerAnimationToggle(pEvent:Event):void {
			if(ConstantsApp.ANIMATION_FRAME_BY_FRAME) {
				character.outfit.poseNextFrame();
				_toolbox.curanimationFrameText.setValues( character.outfit.poseCurrentFrame + "/" + character.outfit.poseTotalFrames );
				return;
			}
			character.animatePose = !character.animatePose;
			if(character.animatePose) {
				character.outfit.play();
			} else {
				character.outfit.stop();
			}
			_toolbox.toggleAnimateButtonAsset(character.animatePose);
		}

		private function _onSaveClicked(pEvent:Event) : void {
			if(!ConstantsApp.ANIMATION_FRAME_BY_FRAME) {
				FewfDisplayUtils.saveAsPNG(this.character, "character");
			} else {
				
				character.outfit.pose.gotoAndPlay(0);
				character.outfit.pose.stop();
				var downloadFrame = function(){
					var fileRef = GameAssets.saveAsPNGFrameByFrameVersion(character, "frame_"+character.getItemData(ITEM.POSE).id+"_"+character.outfit.poseCurrentFrame);
					fileRef.addEventListener("complete", function(e){
						if(character.outfit.poseCurrentFrame >= character.outfit.poseTotalFrames) { return; }
						character.outfit.poseNextFrame();
						downloadFrame();
					});
					
					// trace("downloadFrame", i, frames.length, pName+"_"+(i+1)+".png" );
					// if(i >= frames.length) { return; }
					// var bytes = PNGEncoder.encode(frames[i]);
					// fileRef.save( bytes, pName+"_"+(i+1)+".png" );
					// i++;
				};
				downloadFrame();
					
					
			}
		}

		// Note: does not automatically de-select previous buttons / infobars; do that before calling this
		// This function is required when setting data via parseParams
		private function _updateUIBasedOnCharacter() : void {
			var tPane:TabPane, tData:ItemData, tType:String;
			var tTypes = [ ITEM.HAT, ITEM.HAIR, ITEM.EARS, ITEM.EYES, ITEM.MOUTH, ITEM.NECK, ITEM.TAIL, ITEM.HAND, ITEM.CONTACTS, ITEM.SKIN, ITEM.POSE ], tData:ItemData, tType:String;
			for(var i:int = 0; i < tTypes.length; i++) { tType = tTypes[i];
				tPane = getTabByType(tType);
				
				// Based on what the character is wearing at start, toggle on the appropriate buttons.
				tData = character.getItemData(tType);
				if(tData) {
					var tIndex:int = FewfUtils.getIndexFromArrayWithKeyVal(GameAssets.getArrayByType(tType), "id", tData.id);
					tPane.buttons[ tIndex ].toggleOn();
				}
			}
		}

		private function _onItemToggled(pEvent:FewfEvent) : void {
			var tType = pEvent.data.type;
			var tItemArray:Array = GameAssets.getArrayByType(tType);
			var tInfoBar:ShopInfoBar = getInfoBarByType(tType);

			// De-select all buttons that aren't the clicked one.
			var tButtons:Array = getButtonArrayByType(tType);
			for(var i:int = 0; i < tButtons.length; i++) {
				if(tButtons[i].data.id != pEvent.data.id) {
					if (tButtons[i].pushed)  { tButtons[i].toggleOff(); }
				}
			}

			var tButton:PushButton = tButtons[pEvent.data.id];
			var tData:ItemData;
			// If clicked button is toggled on, equip it. Otherwise remove it.
			if(tButton.pushed) {
				tData = tItemArray[pEvent.data.id];
				setCurItemID(tType, tButton.id);
				this.character.setItemData(tData);

				tInfoBar.addInfo( tData, GameAssets.getColoredItemImage(tData) );
				tInfoBar.showColorWheel(GameAssets.getNumOfCustomColors(tButton.Image as MovieClip) > 0);
			} else {
				_removeItem(tType);
			}
		}

		public function buttonHandClickAfter(pEvent:Event):void {
			toggleItemSelectionOneOff(ITEM.OBJECT, pEvent.target as PushButton, GameAssets.extraObjectWand);
		}

		public function buttonBackClickAfter(pEvent:Event):void {
			toggleItemSelectionOneOff(ITEM.BACK, pEvent.target as PushButton, GameAssets.extraFromage);
		}

		public function buttonBackHandClickAfter(pEvent:Event):void {
			toggleItemSelectionOneOff(ITEM.PAW_BACK, pEvent.target as PushButton, GameAssets.extraBackHand);
		}

		private function toggleItemSelectionOneOff(pType:String, pButton:PushButton, pItemData:ItemData) : void {
			if (pButton.pushed) {
				this.character.setItemData( pItemData );
			} else {
				this.character.removeItem(pType);
			}
		}

		private function _removeItem(pType:String) : void {
			if(pType == ITEM.BACK || pType == ITEM.PAW_BACK || pType == ITEM.OBJECT) {
				this.character.removeItem(pType);
			}
			var tTabPane = getTabByType(pType);
			if(!tTabPane || tTabPane.infoBar.hasData == false) { return; }

			// If item has a default value, toggle it on. otherwise remove item.
			if(pType == ITEM.SKIN || pType == ITEM.POSE) {
				var tDefaultIndex = (pType == ITEM.POSE ? GameAssets.defaultPoseIndex : GameAssets.defaultSkinIndex);
				tTabPane.buttons[tDefaultIndex].toggleOn();
			} else {
				this.character.removeItem(pType);
				tTabPane.infoBar.removeInfo();
				tTabPane.buttons[ tTabPane.selectedButtonIndex ].toggleOff();
			}
		}
		
		private function _onTabClicked(pEvent:flash.events.DataEvent) : void {
			_paneManager.openPane(pEvent.data);
		}

		private function _onRandomizeDesignClicked(pEvent:Event) : void {
			for each(var tItem in ITEM.LAYERING) {
				if(tItem == ITEM.OBJECT || tItem == ITEM.BACK || tItem == ITEM.PAW_BACK || tItem == ITEM.SKIN_COLOR) continue;
				_randomItemOfType(tItem, Math.random() <= 0.65);
			}
			_randomItemOfType(ITEM.POSE, Math.random() <= 0.5);
			(getTabByType(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
		}

		private function _randomItemOfType(pType:String, pSetToDefault:Boolean=false) : void {
			if(getInfoBarByType(pType).isRefreshLocked) { return; }
			if(!pSetToDefault) {
				var tButtons = getButtonArrayByType(pType);
				var tLength = tButtons.length;
				var btn = tButtons[ Math.floor(Math.random() * tLength) ];
				btn.toggleOn();
				var pane:TabPane = getTabByType(pType);
				if(pane.flagOpen) pane.scrollItemIntoView(btn);
			} else {
				_removeItem(pType);
				if(pType == ITEM.SKIN || pType == ITEM.SKIN_COLOR) {
					var pane:TabPane = getTabByType(pType);
					if(pane.flagOpen) pane.scrollItemIntoView(pane.buttons[GameAssets.defaultSkinIndex]);
				}
				else if(pType == ITEM.POSE) {
					var pane:TabPane = getTabByType(pType);
					if(pane.flagOpen) pane.scrollItemIntoView(pane.buttons[GameAssets.defaultPoseIndex]);
				}
			}
		}
		
		private function _reverseGrid(pType:String) : void {
			var tPane = getTabByType(pType);
			tPane.grid.reverse();
			_addDefaultSkinColorButtonIfSkinPane(tPane, pType);
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
			GameAssets.shamanMode = SHAMAN_MODE.OFF;
			for each(var tItem in ITEM.LAYERING) { _removeItem(tItem); }
			_removeItem(ITEM.POSE);
			(getTabByType(TAB_OTHER) as OtherTabPane).updateButtonsBasedOnCurrentData();
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
			private function getTabByType(pType:String) : TabPane {
				return _paneManager.getPane(pType);
			}

			private function getInfoBarByType(pType:String) : ShopInfoBar {
				return getTabByType(pType).infoBar;
			}

			private function getButtonArrayByType(pType:String) : Array {
				return getTabByType(pType).buttons;
			}

			private function getCurItemID(pType:String) : int {
				return getTabByType(pType).selectedButtonIndex;
			}

			private function setCurItemID(pType:String, pID:int) : void {
				getTabByType(pType).selectedButtonIndex = pID;
			}
		//}END Get TabPane data

		//{REGION Color Tab
			private function _onColorPickChanged(pEvent:flash.events.DataEvent):void
			{
				var tVal:int = int(pEvent.data);
				var pane = _paneManager.getPane(COLOR_PANE_ID) as ColorPickerTabPane;
				// Negative number indicates that all colors were randomized
				if(tVal < 0) {
					this.character.getItemData(this.currentlyColoringType).colors = pane.getAllColors();
				} else {
					this.character.getItemData(this.currentlyColoringType).colors[pane.selectedSwatch] = tVal;
				}
				_refreshSelectedItemColor(this.currentlyColoringType);
			}

			private function _onDefaultsButtonClicked(pEvent:Event) : void
			{
				this.character.getItemData(this.currentlyColoringType).setColorsToDefault();
				_refreshSelectedItemColor(this.currentlyColoringType);
				var pane = _paneManager.getPane(COLOR_PANE_ID) as ColorPickerTabPane;
				pane.setupSwatches( this.character.getColors(this.currentlyColoringType) );
			}

			private function _onColorPickHoverPreview(pEvent:FewfEvent) : void {
				// Updated preview data
				GameAssets.swatchHoverPreviewData = pEvent.data;
				// refresh render for anything that uses it
				_refreshSelectedItemColor(this.currentlyColoringType);
			}
			
			private function _refreshSelectedItemColor(pType:String) : void {
				character.updatePose();
				
				var tItemData = this.character.getItemData(pType);
				if(pType != ITEM.SKIN) {
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

			private function _colorButtonClicked(pType:String) : void {
				if(this.character.getItemData(pType) == null) { return; }

				var tData:ItemData = getInfoBarByType(pType).data;
				_paneManager.getPane(COLOR_PANE_ID).infoBar.addInfo( tData, GameAssets.getItemImage(tData) );
				this.currentlyColoringType = pType;
				(_paneManager.getPane(COLOR_PANE_ID) as ColorPickerTabPane).setupSwatches( this.character.getColors(pType) );
				_paneManager.openPane(COLOR_PANE_ID);
				_refreshSelectedItemColor(pType);
			}

			private function _onColorPickerBackClicked(pEvent:Event):void {
				_paneManager.openPane(_paneManager.getPane(COLOR_PANE_ID).infoBar.data.type);
			}

			private function _eyeDropButtonClicked(pType:String) : void {
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
				_paneManager.openPane(_paneManager.getPane(COLOR_FINDER_PANE_ID).infoBar.data.type);
			}

			private function _onConfigColorPickChanged(pEvent:flash.events.DataEvent):void
			{
				var tVal:uint = Math.abs(int(pEvent.data));
				_setConfigShamanColor(tVal);
			}
			
			private function _setConfigShamanColor(val:uint) : void {
				/*_paneManager.getPane(TAB_OTHER).updateCustomColor(configCurrentlyColoringType, val);*/
				GameAssets.shamanColor = val;
				character.updatePose();
			}

			private function _shamanColorButtonClicked(/*pType:String, pColor:int*/) : void {
				/*this.configCurrentlyColoringType = pType;*/
				(_paneManager.getPane(CONFIG_COLOR_PANE_ID) as ColorPickerTabPane).setupSwatches( [ GameAssets.shamanColor ] );
				_paneManager.openPane(CONFIG_COLOR_PANE_ID);
			}
		//}END Color Tab
	}
}
