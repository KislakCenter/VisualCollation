import React from 'react';
import logoImg from '../../assets/vceditor_logo.png';
import CircularProgress from 'material-ui/CircularProgress';

/** Stateless functional component for the app loading screen */
const AppLoadingScreen = props => {
  const logo = <img src={logoImg} alt="logo" width="100%" />;
  if (props.loading) {
    return (
      <div className="appLoading">
        <div className="container">
          <div className="logo">{logo}</div>
          <div className="progress">
            <CircularProgress color="#4ED6CB" size={60} />
          </div>
        </div>
      </div>
    );
  } else {
    return <div></div>;
  }
};
export default AppLoadingScreen;
