import React from 'react';
import Panel from './Panel';

/** Stateless functional component for the Managers panel in sidebar of project edit page */
const ManagersPanel = props => {
  return (
    <Panel
      title="Managers"
      defaultOpen={true}
      noPadding={true}
      tabIndex={props.popUpActive ? -1 : 0}
    >
      <button
        className={
          props.managerMode === 'collationManager'
            ? 'manager active'
            : 'manager'
        }
        onClick={() => props.changeManagerMode('collationManager')}
        tabIndex={props.popUpActive ? -1 : 0}
        aria-label="Collation Manager"
      >
        Collation
      </button>
      <button
        className={
          props.managerMode === 'termsManager' ? 'manager active' : 'manager'
        }
        onClick={() => props.changeManagerMode('termsManager')}
        tabIndex={props.popUpActive ? -1 : 0}
        aria-label="Taxonomies Manager"
      >
        Taxonomies
      </button>
      <button
        className={
          props.managerMode === 'imageManager' ? 'manager active' : 'manager'
        }
        onClick={() => props.changeManagerMode('imageManager')}
        tabIndex={props.popUpActive ? -1 : 0}
        aria-label="Image Manager"
      >
        Images
      </button>
    </Panel>
  );
};
export default ManagersPanel;
