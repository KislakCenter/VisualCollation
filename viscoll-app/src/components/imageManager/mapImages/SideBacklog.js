import React, { Component } from 'react';
import IconButton from 'material-ui/IconButton';
import Add from 'material-ui/svg-icons/content/add-circle-outline';
import VirtualList from 'react-tiny-virtual-list';

/** Panel for unmapped sides */
export default class SideBacklog extends Component {

  renderSideItem = (index, style) => {
    const sideID = this.props.sideIDs[index];
    const sideType = sideID.charAt(0)==="R"? "recto" : "verso";
    const side = sideType === "recto" ? this.props.Rectos[sideID] : this.props.Versos[sideID];
    const folioNumber = side.folio_number && side.folio_number!=="" ? "("+side.folio_number+")" : "";
    const pageNumber = side.page_number && side.page_number!=="" ? "("+side.page_number+")" : "";
    const leafOrder = this.props.leafIDs.indexOf(side.parentID)+1;
    let actionButtons = (
      <div style={{paddingRight: "1em"}} onClick={(event)=> event.stopPropagation()}>
        <IconButton 
          tooltip="Move To Mapping" 
          aria-label={"Move leaf " + leafOrder + " " + sideType + " to mapping"}
          onClick={()=>this.props.moveItemsToMap([sideID], "sideMapBoard", "sideBacklog")} 
          tabIndex={this.props.tabIndex}
        >
          <Add />
        </IconButton>
      </div>
    );
    let activeStyle = {};
    if (this.props.selectedObjects.members.includes(sideID))
      activeStyle = {backgroundColor: "#4ED6CB"}
    return (
      <div key={side.id} style={{...style, ...activeStyle}} className="moveableItem" onClick={(event)=>this.props.handleObjectClick(this.props.id, sideID, event)}>
        <div className="text">
          {"Leaf " + leafOrder + " " + side.memberType + " " + folioNumber + " " + pageNumber}
        </div>
        {actionButtons}
      </div>
    );
  }

  render() {
    if (this.props.id==="sideMapBoard") {
      return (
        <div>
          <VirtualList
            width='100%'
            height='40vh'
            itemSize={51}
            itemCount={this.props.sideIDs.length}
            renderItem={({index, style}) => this.renderSideItem(index, style)}
            overscanCount={10}
            estimatedItemSize={400}
          />
        </div>
      );
    }

    // sideBacklog
    return (
      <VirtualList
        width='100%'
        height='32vh'
        itemSize={51}
        itemCount={this.props.sideIDs.length}
        renderItem={({index, style}) => this.renderSideItem(index, style)}
        overscanCount={10}
        estimatedItemSize={400}
      />
    );

  }
}
